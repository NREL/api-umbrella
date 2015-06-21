local _M = {}

local api_store = require "api_store"
local cjson = require "cjson"
local http = require "resty.http"
local inspect = require "inspect"
local lock = require "resty.lock"
local plutils = require "pl.utils"
local tablex = require "pl.tablex"
local types = require "pl.types"
local utils = require "utils"
local load_backends = require "load_backends"

local append_array = utils.append_array
local cache_computed_settings = utils.cache_computed_settings
local escape = plutils.escape
local get_packed = utils.get_packed
local is_empty = types.is_empty
local set_packed = utils.set_packed
local size = tablex.size
local split = plutils.split

local lock = lock:new("my_locks", {
  ["timeout"] = 0,
})

local setlock = lock:new("my_locks", {
  ["timeout"] = 0,
})

local loaded_version = nil
local delay = 0.3  -- in seconds
local new_timer = ngx.timer.at
local log = ngx.log
local ERR = ngx.ERR

local function cache_computed_api(api)
  if not api then return end

  if api["url_matches"] then
    for _, url_match in ipairs(api["url_matches"]) do
      url_match["_frontend_prefix_matcher"] = "^" .. escape(url_match["frontend_prefix"])
    end
  end

  if api["rewrites"] then
    for _, rewrite in ipairs(api["rewrites"]) do
      rewrite["http_method"] = string.lower(rewrite["http_method"])

      -- Route pattern matching implementation based on
      -- https://github.com/bjoerge/route-pattern
      -- TODO: Cleanup!
      if rewrite["matcher_type"] == "route" then
        local backend_replacement = string.gsub(rewrite["backend_replacement"], "{{([^{}]-)}}", "{{{%1}}}")
        local parts = split(backend_replacement, "?", true, 2)
        rewrite["_backend_replacement_path"] = parts[1]
        rewrite["_backend_replacement_args"] = parts[2]

        local parts = split(rewrite["frontend_matcher"], "?", true, 2)
        local path = parts[1]
        local args = parts[2]

        local escapeRegExp = "[\\-{}\\[\\]+?.,\\\\^$|#\\s]"
        local namedParam = [[:(\w+)]]
        local splatNamedParam = [[\*(\w+)]]
        local subPath = [[\*([^\w]|$)]]

        local frontend_path_regex, n, err = ngx.re.gsub(path, escapeRegExp, "\\$0")
        frontend_path_regex = ngx.re.gsub(frontend_path_regex, subPath, [[.*?$1]])
        frontend_path_regex = ngx.re.gsub(frontend_path_regex, namedParam, [[(?<$1>[^/]+)]])
        frontend_path_regex = ngx.re.gsub(frontend_path_regex, splatNamedParam, [[(?<$1>.*?)]])
        frontend_path_regex = ngx.re.gsub(frontend_path_regex, "/$", "")
        rewrite["_frontend_path_regex"] = "^" .. frontend_path_regex .. "/?$"

        if args then
          args = ngx.decode_args(args)
          rewrite["_frontend_args_length"] = size(args)
          rewrite["_frontend_args"] = {}
          for key, value in pairs(args) do
            if key == "*" and value == true then
              rewrite["_frontend_args_allow_wildcards"] = true
            else
              rewrite["_frontend_args"][key] = {}
              if type(value) == "string" and string.sub(value, 1, 1) == ":" then
                rewrite["_frontend_args"][key]["named_capture"] = string.sub(value, 2, -1)
              else
                rewrite["_frontend_args"][key]["must_equal"] = value
              end
            end
          end
        end
      end
    end
  end
end

local function cache_computed_sub_settings(sub_settings)
  if not sub_settings then return end

  for _, sub_setting in ipairs(sub_settings) do
    if sub_setting["http_method"] then
      sub_setting["http_method"] = string.lower(sub_setting["http_method"])
    end

    if sub_setting["settings"] then
      cache_computed_settings(sub_setting["settings"])
    end
  end
end

local function set_apis(apis)
  local elapsed, err = setlock:lock("set_apis")
  if err then
    return
  end

  local data = {
    ["apis_by_host"] = {},
  }

  for _, api in ipairs(apis) do
    cache_computed_api(api)
    cache_computed_settings(api["settings"])
    cache_computed_sub_settings(api["sub_settings"])

    if not api["_id"] then
      api["_id"] = ndk.set_var.set_secure_random_alphanum(32)
    end

    local host = api["frontend_host"]
    if host then
      if not data["apis_by_host"][host] then
        data["apis_by_host"][host] = {}
      end
      table.insert(data["apis_by_host"][host], api)
    end
  end

  set_packed(ngx.shared.apis, "packed_data", data)
  load_backends.setup_backends()

  local ok, err = setlock:unlock()
  if not ok then
    ngx.log(ngx.ERR, "failed to unlock: ", err)
  end
end

local function finalize_check(premature, version, last_fetched_at)
  if premature then
    return
  end

  -- Only consider this version of the config loaded and upstreams initialized
  -- the *second* time we see it when nginx workers are starting for the first
  -- time. This is ugly, but it's the only way I can currently figure to
  -- prevent race conditions across processes during nginx SIGHUP reloads.
  --
  -- This tries to prevent the race condition where nginx gets reloaded, and
  -- the new processes spin up while an old process was in the middle of
  -- loading the API config. Due to how dyups works, we need to initialize all
  -- the upstreams in the new workers before allowing requests to be processes.
  -- This means we need to ignore the old process completing any upstream
  -- config (since that doesn't help the new processes).
  --
  -- TODO: balancer_by_lua is supposedly coming soon, which I think might offer
  -- a much cleaner way to deal with all this versus what we're currently doing
  -- with dyups. Revisit if that gets released.
  -- https://groups.google.com/d/msg/openresty-en/NS2dWt-xHsY/PYzi5fiiW8AJ
  if ngx.shared.apis:get("nginx_reloading_guard") then
    ngx.shared.apis:set("upstreams_inited", true)

    if last_fetched_at then
      ngx.shared.apis:set("last_fetched_at", ngx.now())
    end

    if version then
      ngx.shared.apis:set("version", version)
      loaded_version = version
    end
  else
    ngx.shared.apis:set("nginx_reloading_guard", true)
  end

  local ok, err = lock:unlock()
  if not ok then
    ngx.log(ngx.ERR, "failed to unlock: ", err)
  end
end

local function do_check()
  local elapsed, err = lock:lock("load_apis")
  if err then
    return
  end

  local last_fetched_version = ngx.shared.apis:get("version") or 0

  local httpc = http.new()
  local res, err = httpc:request_uri("http://127.0.0.1:8181/docs/api_umbrella/" .. config["mongodb"]["_database"] .. "/config_versions", {
    query = {
      extended_json = "true",
      limit = 1,
      sort = "-version",
      query = cjson.encode({
        version = {
          ["$gt"] = {
            ["$date"] = last_fetched_version,
          },
        },
      }),
    },
  })

  local results = nil
  local runtime_config_apis = nil

  local version = nil
  local last_fetched_at = nil

  if not err and res.body then
    local response = cjson.decode(res.body)
    if response and response["data"] and response["data"] and response["data"][1] then
      result = response["data"][1]
      if result and result["config"] and result["config"]["apis"] then
        runtime_config_apis = result["config"]["apis"]
        set_packed(ngx.shared.apis, "packed_runtime_config_apis", runtime_config_apis)
      end

      version = result["version"]["$date"]
    end

    if not err then
      last_fetched_at = ngx.now()
    end
  end

  if runtime_config_apis or not ngx.shared.apis:get("version") or not loaded_version then
    local config_apis = config["_combined_apis"] or {}

    -- If for some reason, fetching the runtime config has failed, always use
    -- the old configuration we last saw.
    if not runtime_config_apis then
      runtime_config_apis = get_packed(ngx.shared.apis, "packed_runtime_config_apis") or {}
    end

    local all_apis = {}
    append_array(all_apis, config_apis)
    append_array(all_apis, runtime_config_apis)
    set_apis(all_apis)
  end

  -- Defer setting the shared variables indicating the runtime config has been
  -- loaded with a timer. Since timers don't run when a process is exiting,
  -- this is to help ensure we don't set these variables if we're in the midst
  -- of a load that's still running on an nginx process that is exiting (due to
  -- a SIGHUP reload).
  --
  -- This tries to prevent the race condition where nginx gets reloaded, and
  -- the new processes spin up while an old process was in the middle of
  -- loading the API config. Due to how dyups works, we need to initialize all
  -- the upstreams in the new workers before allowing requests to be processes.
  -- This means we need to ignore the old process completing any upstream
  -- config (since that doesn't help the new processes).
  --
  -- TODO: balancer_by_lua is supposedly coming soon, which I think might offer
  -- a much cleaner way to deal with all this versus what we're currently doing
  -- with dyups. Revisit if that gets released.
  -- https://groups.google.com/d/msg/openresty-en/NS2dWt-xHsY/PYzi5fiiW8AJ
  local ok, err = new_timer(0, finalize_check, version, last_fetched_at)
  if not ok then
    if err ~= "process exiting" then
      ngx.log(ngx.ERR, "failed to create timer: ", err)
    end
  end
end

local function check(premature)
  if premature then
    return
  end

  local ok, err = pcall(do_check)
  if not ok then
    ngx.log(ngx.ERR, "failed to run api load cycle: ", err)
  end

  local ok, err = new_timer(delay, check)
  if not ok then
    if err ~= "process exiting" then
      ngx.log(ngx.ERR, "failed to create timer: ", err)
    end

    return
  end
end

function _M.spawn()
  local ok, err = new_timer(0, check)
  if not ok then
    log(ERR, "failed to create timer: ", err)
    return
  end
end

return _M
