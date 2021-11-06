local config = require "api-umbrella.proxy.models.file_config"
local escape_regex = require "api-umbrella.utils.escape_regex"
local haproxy_config_template = require "api-umbrella.proxy.haproxy_config_template"
local host_normalize = require "api-umbrella.utils.host_normalize"
local http = require "resty.http"
local int64 = require "api-umbrella.utils.int64"
local json_encode = require "api-umbrella.utils.json_encode"
local mustache_unescape = require "api-umbrella.utils.mustache_unescape"
local packed_shared_dict = require "api-umbrella.utils.packed_shared_dict"
local plutils = require "pl.utils"
local psl = require "api-umbrella.utils.psl"
local startswith = require("pl.stringx").startswith
local tablex = require "pl.tablex"
local utils = require "api-umbrella.proxy.utils"
local xpcall_error_handler = require "api-umbrella.utils.xpcall_error_handler"

local append_array = utils.append_array
local cache_computed_settings = utils.cache_computed_settings
local deepcopy = tablex.deepcopy
local safe_set_packed = packed_shared_dict.safe_set_packed
local size = tablex.size
local split = plutils.split

local _M = {}

local function set_hostname_regex(record, key)
  if record[key] then
    local host = host_normalize(record[key])

    local normalized_key = "_" .. key .. "_normalized"
    record[normalized_key] = host

    local wildcard_regex_key = "_" .. key .. "_wildcard_regex"
    if string.sub(host, 1, 1)  == "." then
      record[wildcard_regex_key] = "^(.+\\.|)" .. escape_regex(string.sub(host, 2)) .. "$"
    elseif string.sub(host, 1, 2) == "*." then
      record[wildcard_regex_key] = "^(.+)" .. escape_regex(string.sub(host, 2)) .. "$"
    elseif host == "*" then
      record[wildcard_regex_key] = "^(.+)$"
    end
  end
end

local function cache_computed_api(api)
  if not api then return end

  if api["frontend_host"] then
    set_hostname_regex(api, "frontend_host")
  end

  if api["backend_host"] == "" then
    api["backend_host"] = nil
  end

  if api["backend_host"] then
    api["_backend_host_normalized"] = host_normalize(api["backend_host"])
  end

  if api["servers"] then
    for index, server in ipairs(api["servers"]) do
      if not server["id"] then
        server["id"] = api["id"] .. "-" .. index
      end
    end
  end

  if api["url_matches"] then
    for _, url_match in ipairs(api["url_matches"]) do
      url_match["_frontend_prefix_regex"] = "^" .. escape_regex(url_match["frontend_prefix"])
      url_match["_backend_prefix_regex"] = "^" .. escape_regex(url_match["backend_prefix"])

      url_match["_frontend_prefix_contains_backend_prefix"] = false
      if startswith(url_match["frontend_prefix"], url_match["backend_prefix"]) then
        url_match["_frontend_prefix_contains_backend_prefix"] = true
      end

      url_match["_backend_prefix_contains_frontend_prefix"] = false
      if startswith(url_match["backend_prefix"], url_match["frontend_prefix"]) then
        url_match["_backend_prefix_contains_frontend_prefix"] = true
      end
    end
  end

  if api["rewrites"] then
    for _, rewrite in ipairs(api["rewrites"]) do
      rewrite["http_method"] = string.lower(rewrite["http_method"])

      -- Route pattern matching implementation based on
      -- https://github.com/bjoerge/route-pattern
      -- TODO: Cleanup!
      if rewrite["matcher_type"] == "route" and rewrite["frontend_matcher"] and rewrite["backend_replacement"] then
        local backend_replacement = mustache_unescape(rewrite["backend_replacement"])
        local backend_parts = split(backend_replacement, "?", true, 2)
        rewrite["_backend_replacement_path"] = backend_parts[1]
        rewrite["_backend_replacement_args"] = backend_parts[2]

        local frontend_parts = split(rewrite["frontend_matcher"], "?", true, 2)
        local path = frontend_parts[1]
        local args = frontend_parts[2]

        local escapeRegExp = "[\\-{}\\[\\]+?.,\\\\^$|#\\s]"
        local namedParam = [[:(\w+)]]
        local splatNamedParam = [[\*(\w+)]]
        local subPath = [[\*([^\w]|$)]]

        local frontend_path_regex, _, gsub_err = ngx.re.gsub(path, escapeRegExp, "\\$0")
        if gsub_err then
          ngx.log(ngx.ERR, "regex error: ", gsub_err)
        end

        frontend_path_regex, _, gsub_err = ngx.re.gsub(frontend_path_regex, subPath, [[.*?$1]])
        if gsub_err then
          ngx.log(ngx.ERR, "regex error: ", gsub_err)
        end

        frontend_path_regex, _, gsub_err = ngx.re.gsub(frontend_path_regex, namedParam, [[(?<$1>[^/]+)]])
        if gsub_err then
          ngx.log(ngx.ERR, "regex error: ", gsub_err)
        end

        frontend_path_regex, _, gsub_err = ngx.re.gsub(frontend_path_regex, splatNamedParam, [[(?<$1>.*?)]])
        if gsub_err then
          ngx.log(ngx.ERR, "regex error: ", gsub_err)
        end

        frontend_path_regex, _, gsub_err = ngx.re.gsub(frontend_path_regex, "/$", "")
        if gsub_err then
          ngx.log(ngx.ERR, "regex error: ", gsub_err)
        end

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
    else
      sub_setting["settings"] = {}
    end
  end
end

local function sort_by_frontend_host_length(a, b)
  return string.len(tostring(a["frontend_host"])) > string.len(tostring(b["frontend_host"]))
end

local function parse_api(api)
  if not api["id"] then
    api["id"] = ngx.md5(json_encode(api))
  end

  cache_computed_api(api)
  cache_computed_settings(api["settings"])
  cache_computed_sub_settings(api["sub_settings"])
end

local function parse_apis(apis)
  for _, api in ipairs(apis) do
    local ok, err = xpcall(parse_api, xpcall_error_handler, api)
    if not ok then
      ngx.log(ngx.ERR, "failed parsing API config: ", err)
    end
  end
end

local function parse_website_backend(website_backend)
  if not website_backend["id"] then
    website_backend["id"] = ngx.md5(json_encode(website_backend))
  end

  if website_backend["frontend_host"] then
    set_hostname_regex(website_backend, "frontend_host")
  end

  website_backend["_backend_host"] = website_backend["backend_host"]
  if not website_backend["_backend_host"] then
    website_backend["_backend_host"] = website_backend["server_host"]
  end
end

local function parse_website_backends(website_backends)
  for _, website_backend in ipairs(website_backends) do
    local ok, err = xpcall(parse_website_backend, xpcall_error_handler, website_backend)
    if not ok then
      ngx.log(ngx.ERR, "failed parsing website backend config: ", err)
    end
  end

  table.sort(website_backends, sort_by_frontend_host_length)
end

local function build_known_api_domains(apis)
  local domains = {}

  if config["web"]["default_host"] then
    domains[config["web"]["default_host"]] = 1
  end

  if config["router"]["web_app_host"] then
    domains[config["router"]["web_app_host"]] = 1
  end

  if config["hosts"] then
    for _, host in ipairs(config["hosts"]) do
      if host and host["hostname"] then
        domains[host["hostname"]] = 1
      end
    end
  end

  if apis then
    for _, api in ipairs(apis) do
      if api and api["frontend_host"] then
        domains[api["frontend_host"]] = 1
      end
    end
  end

  return domains
end

local function build_known_private_suffix_domains(known_api_domains, website_backends)
  local domains = {}

  if known_api_domains then
    for domain, _ in pairs(known_api_domains) do
      if domain then
        local private_suffix_domain = psl:registrable_domain(domain)
        if private_suffix_domain then
          domains[private_suffix_domain] = 1
        end
      end
    end
  end

  if website_backends then
    for _, website_backend in ipairs(website_backends) do
      if website_backend and website_backend["frontend_host"] then
        local private_suffix_domain = psl:registrable_domain(website_backend["frontend_host"])
        if private_suffix_domain then
          domains[private_suffix_domain] = 1
        end
      end
    end
  end

  return domains
end

local function build_active_config(apis, website_backends)
  parse_apis(apis)
  parse_website_backends(website_backends)

  local api_ok, known_api_domains = xpcall(build_known_api_domains, xpcall_error_handler, apis)
  if not api_ok then
    ngx.log(ngx.ERR, "failed building known API domains: ", known_api_domains)
    known_api_domains = nil
  end

  local private_ok, known_private_suffix_domains = xpcall(build_known_private_suffix_domains, xpcall_error_handler, known_api_domains, website_backends)
  if not private_ok then
    ngx.log(ngx.ERR, "failed building known API domains: ", known_private_suffix_domains)
    known_private_suffix_domains = nil
  end

  local active_config = {
    apis = apis,
    websites = website_backends,
    known_domains = {
      apis = known_api_domains,
      private_suffixes = known_private_suffix_domains,
    },
  }

  return active_config
end

local function get_combined_apis(file_config, db_config)
  local file_config_apis = deepcopy(file_config["_apis"]) or {}
  local db_config_apis = db_config["apis"] or {}

  local all_apis = {}
  append_array(all_apis, file_config_apis)
  append_array(all_apis, db_config_apis)
  return all_apis
end

local function get_combined_website_backends(file_config, db_config)
  local file_config_website_backends = deepcopy(file_config["_website_backends"]) or {}
  local db_config_website_backends = db_config["website_backends"] or {}

  local all_website_backends = {}
  append_array(all_website_backends, file_config_website_backends)
  append_array(all_website_backends, db_config_website_backends)
  return all_website_backends
end

local function haproxy_version()
  local httpc = http.new()

  local connect_ok, connect_err = httpc:connect({
    scheme = "http",
    host = "127.0.0.1",
    port = config["haproxy"]["config_version_port"],
  })
  if not connect_ok then
    httpc:close()
    return nil, "haproxy config-version connect error: " .. (connect_err or "")
  end

  local res, err = httpc:request({
    method = "GET",
    path = "/",
  })
  if err then
    httpc:close()
    return nil, "haproxy config-version request error: " .. (err or "")
  end

  local body, body_err = res:read_body()
  if body_err then
    httpc:close()
    return nil, "haproxy dataplaneapi read body error: " .. (body_err or "")
  end
  ngx.log(ngx.ERR, "CONFIG-VERSION STATUS: ", res.status)
  ngx.log(ngx.ERR, "CONFIG-VERSION HEADERS: ", json_encode(res.headers))
  ngx.log(ngx.ERR, "CONFIG-VERSION BODY: ", body)

  local keepalive_ok, keepalive_err = httpc:set_keepalive()
  if not keepalive_ok then
    httpc:close()
    return nil, "haproxy config-version keepalive error: " .. (keepalive_err or "")
  end
end

local function set_haproxy_config(active_config, config_version)
  local haproxy_config, haproxy_err = haproxy_config_template({
    config = config,
    api_backends = active_config["apis"],
    website_backends = active_config["websites"],
    config_version = config_version
  })
  if haproxy_err then
    return nil, "haproxy config template error: " .. (haproxy_err .. "")
  end

  local httpc = http.new()

  local connect_ok, connect_err = httpc:connect({
    scheme = "http",
    host = "127.0.0.1",
    port = config["haproxy"]["dataplaneapi"]["port"],
  })
  if not connect_ok then
    httpc:close()
    return nil, "haproxy dataplaneapi connect error: " .. (connect_err or "")
  end

  ngx.log(ngx.ERR, "BEFORE CONFIG-VERSION: ", config_version)
  haproxy_version()

  local res, err = httpc:request({
    method = "POST",
    headers = {
     ["Authorization"] = "Basic " .. ngx.encode_base64("admin:adminpwd"),
     ["Content-Type"] = "text/plain",
    },
    path = "/v2/services/haproxy/configuration/raw",
    query = {
      skip_version = "true",
      force_reload = "true",
    },
    body = haproxy_config,
  })
  if err then
    httpc:close()
    return nil, "haproxy dataplaneapi request error: " .. (err or "")
  end

  local body, body_err = res:read_body()
  if body_err then
    httpc:close()
    return nil, "haproxy dataplaneapi read body error: " .. (body_err or "")
  end
  ngx.log(ngx.ERR, "STATUS: ", res.status)
  ngx.log(ngx.ERR, "HEADERS: ", json_encode(res.headers))
  ngx.log(ngx.ERR, "BODY: ", body)

  ngx.log(ngx.ERR, "AFTER CONFIG-VERSION: ", config_version)
  haproxy_version()

  ngx.sleep(0.5)

  ngx.log(ngx.ERR, "AFTER SLEEP CONFIG-VERSION: ", config_version)
  haproxy_version()

  -- local res, err = httpc:request({
  --   method = "GET",
  --   headers = {
  --    ["Authorization"] = "Basic " .. ngx.encode_base64("admin:adminpwd"),
  --   },
  --   path = "/v2/services/haproxy/configuration/version",
  -- })
  -- if err then
  --   httpc:close()
  --   return nil, "haproxy dataplaneapi request error: " .. (err or "")
  -- end

  -- local body, body_err = res:read_body()
  -- if body_err then
  --   httpc:close()
  --   return nil, "haproxy dataplaneapi read body error: " .. (body_err or "")
  -- end
  -- ngx.log(ngx.ERR, "AFTER SLEEP VERSION STATUS: ", res.status)
  -- ngx.log(ngx.ERR, "AFTER SLEEP VERSION HEADERS: ", json_encode(res.headers))
  -- ngx.log(ngx.ERR, "AFTER SLEEP VERSION BODY: ", body)

  -- local res, err = httpc:request({
  --   method = "GET",
  --   headers = {
  --    ["Authorization"] = "Basic " .. ngx.encode_base64("admin:adminpwd"),
  --   },
  --   path = "/v2/services/haproxy/reloads",
  -- })
  -- if err then
  --   httpc:close()
  --   return nil, "haproxy dataplaneapi request error: " .. (err or "")
  -- end

  -- local body, body_err = res:read_body()
  -- if body_err then
  --   httpc:close()
  --   return nil, "haproxy dataplaneapi read body error: " .. (body_err or "")
  -- end
  -- ngx.log(ngx.ERR, "RELOADS STATUS: ", res.status)
  -- ngx.log(ngx.ERR, "RELOADS HEADERS: ", json_encode(res.headers))
  -- ngx.log(ngx.ERR, "RELOADS BODY: ", body)

  local keepalive_ok, keepalive_err = httpc:set_keepalive()
  if not keepalive_ok then
    httpc:close()
    return nil, "haproxy dataplaneapi keepalive error: " .. (keepalive_err or "")
  end
end

function _M.set(db_config)
  local file_config = config
  if not db_config then
    db_config = {}
  end

  local apis = get_combined_apis(file_config, db_config)
  local website_backends = get_combined_website_backends(file_config, db_config)

  local active_config = build_active_config(apis, website_backends)
  local previous_packed_config = ngx.shared.active_config:get("packed_data")

  local db_version = db_config["version"]
  if db_version then
    db_version = int64.to_string(db_version)
  end
  ngx.log(ngx.ERR, "db_version: ", db_version)

  local file_version = file_config["version"]

  local config_version = (db_version or "") .. ":" .. (file_version or "")

  set_haproxy_config(active_config, config_version)

  local set_ok, set_err = safe_set_packed(ngx.shared.active_config, "packed_data", active_config)
  if not set_ok then
    ngx.log(ngx.ERR, "failed to set 'packed_data' in 'active_config' shared dict: ", set_err)

    -- If the new config exceeds the amount of available space, `safe_set` will
    -- still result in the previous value for `packed_data` getting removed
    -- (see https://github.com/openresty/lua-nginx-module/issues/1365). This
    -- effectively unpublishes all configuration, which can be disruptive if
    -- your new config happens to exceed the allocated space.
    --
    -- So to more safely handle this scenario, revert `packed_data` back to the
    -- previously set value (that presumably fits in memory) so that the
    -- previous config remains in place. The new configuration will go
    -- unpublished, but this at least keeps the system up in the previous
    -- state.
    --
    -- When this occurs, we will go ahead and set the `db_version` and
    -- `file_version` to the new versions, even though this isn't entirely
    -- accurate (since we're reverting to the previous config). But by
    -- pretending the data was successfully set, this prevents the system from
    -- looping indefinitely and trying to set the config over and over to a
    -- version that won't fit in memory. In this situation, there's not much
    -- else we can do, since the shdict memory needs to be increased.
    set_ok, set_err = ngx.shared.active_config:safe_set("packed_data", previous_packed_config)
    if not set_ok then
      ngx.log(ngx.ERR, "failed to set 'packed_data' in 'active_config' shared dict: ", set_err)
    end
  end

  set_ok, set_err = ngx.shared.active_config:safe_set("db_version", db_version)
  if not set_ok then
    ngx.log(ngx.ERR, "failed to set 'db_version' in 'active_config' shared dict: ", set_err)
  end

  set_ok, set_err = ngx.shared.active_config:safe_set("file_version", file_version)
  if not set_ok then
    ngx.log(ngx.ERR, "failed to set 'file_version' in 'active_config' shared dict: ", set_err)
  end

  set_ok, set_err = ngx.shared.active_config:safe_set("worker_group_setup_complete:" .. WORKER_GROUP_ID, true)
  if not set_ok then
    ngx.log(ngx.ERR, "failed to set 'worker_group_setup_complete' in 'active_config' shared dict: ", set_err)
  end
end

return _M
