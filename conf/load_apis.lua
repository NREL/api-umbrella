local _M = {}

local api_store = require "api_store"
local bson = require "resty-mongol.bson"
local inspect = require "inspect"
local lock = require "resty.lock"
local mongol = require "resty-mongol"
local plutils = require "pl.utils"
local tablex = require "pl.tablex"
local utils = require "utils"

local append_array = utils.append_array
local cache_computed_settings = utils.cache_computed_settings
local deepcopy = tablex.deepcopy
local escape = plutils.escape
local get_utc_date = bson.get_utc_date
local get_packed = utils.set_packed
local set_packed = utils.set_packed
local size = tablex.size
local split = plutils.split

local lock = lock:new("my_locks", {
  ["timeout"] = 0,
})

local delay = 0.05  -- in seconds
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
  local data = {
    ["apis"] = {},
    ["ids_by_host"] = {},
  }

  for _, api in ipairs(apis) do
    cache_computed_api(api)
    cache_computed_settings(api["settings"])
    cache_computed_sub_settings(api["sub_settings"])

    if not api["_id"] then
      api["_id"] = ndk.set_var.set_secure_random_alphanum(32)
    end

    local api_id = api["_id"]
    data["apis"][api_id] = api

    local host = api["frontend_host"]
    if not data["ids_by_host"][host] then
      data["ids_by_host"][host] = {}
    end
    table.insert(data["ids_by_host"][host], api_id)
  end

  set_packed(ngx.shared.apis, "packed_data", data)
end

local function do_check()
  local elapsed, err = lock:lock("load_apis")
  if err then
    return
  end

  api_store.update_worker_cache_if_necessary()

  local conn = mongol()
  conn:set_timeout(1000)

  local ok, err = conn:connect("127.0.0.1", 27017)
  if not ok then
    log(ERR, "connect failed: "..err)
  end

  local db = conn:new_db_handle("api_umbrella_test")
  local col = db:get_col("config_versions")

  local last_fetched_version = ngx.shared.apis:get("version") or 0
  local query = {
    ["$query"] = {
      version = {
        ["$gt"] = get_utc_date(last_fetched_version),
      },
    },
    ["$orderby"] = {
      version = -1
    },
  }
  local v = col:find_one(query)
  if v and v["config"] and v["config"]["apis"] then
    local apis = config["internal_apis"] or {}
    append_array(apis, config["apis"] or {})
    append_array(apis, v["config"]["apis"])

    ngx.log(ngx.ERR, inspect(v["config"]["apis"]))
    set_apis(apis)
    ngx.shared.apis:set("version", ngx.now())
  end

  conn:set_keepalive(10000, 5)

  local ok, err = lock:unlock()
  if not ok then
    ngx.log(ngx.ERR, "failed to unlock: ", err)
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

function _M.init()
  local config_apis = deepcopy(config["internal_apis"] or {})
  append_array(config_apis, config["apis"] or {})
  set_packed(ngx.shared.apis, "packed_config_apis", config_apis)

  local db_apis = get_packed(ngx.shared.apis, "packed_db_apis") or {}

  local all_apis = {}
  append_array(all_apis, config_apis)
  append_array(all_apis, db_apis)

  set_apis(all_apis)
  api_store.update_worker_cache()
end

return _M
