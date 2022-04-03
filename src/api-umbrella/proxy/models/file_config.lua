local append_array = require "api-umbrella.utils.append_array"
local cache_computed_api_backend_settings = require("api-umbrella.utils.active_config_store.cache_computed_api_backend_settings")
local lyaml = require "lyaml"
local nillify_yaml_nulls = require "api-umbrella.utils.nillify_yaml_nulls"

local log = ngx.log
local ERR = ngx.ERR

local function read_file()
  local f, err = io.open(os.getenv("API_UMBRELLA_RUNTIME_CONFIG"), "rb")
  if err then
    log(ERR, "failed to open config file: ", err)
    return nil
  end

  local content = f:read("*all")
  f:close()

  local data = lyaml.load(content)
  nillify_yaml_nulls(data)
  return data
end

local function set_defaults(data)
  if data["internal_apis"] then
    for _, api in ipairs(data["internal_apis"]) do
      if api["frontend_host"] == "{{router.web_app_host}}" then
        api["frontend_host"] = data["router"]["web_app_host"]
      end

      if api["servers"] then
        for _, server in ipairs(api["servers"]) do
          if server["host"] == "{{web.host}}" then
            server["host"] = data["web"]["host"]
          elseif server["host"] == "{{api_server.host}}" then
            server["host"] = data["api_server"]["host"]
          end

          if server["port"] == "{{web.port}}" then
            server["port"] = data["web"]["port"]
          elseif server["port"] == "{{api_server.port}}" then
            server["port"] = data["api_server"]["port"]
          end
        end
      end
    end
  end

  if data["internal_website_backends"] then
    for _, website in ipairs(data["internal_website_backends"]) do
      if website["frontend_host"] == "{{router.web_app_host}}" then
        website["frontend_host"] = data["router"]["web_app_host"]
      end

      if website["server_host"] == "{{static_site.host}}" then
        website["server_host"] = data["static_site"]["host"]
      end

      if website["server_port"] == "{{static_site.port}}" then
        website["server_port"] = data["static_site"]["port"]
      end
    end
  end

  local combined_apis = {}
  append_array(combined_apis, data["internal_apis"] or {})
  append_array(combined_apis, data["apis"] or {})
  data["_apis"] = combined_apis
  data["apis"] = nil
  data["internal_apis"] = nil

  local combined_website_backends = {}
  append_array(combined_website_backends, data["internal_website_backends"] or {})
  append_array(combined_website_backends, data["website_backends"] or {})
  data["_website_backends"] = combined_website_backends
  data["website_backends"] = nil
  data["internal_website_backends"] = nil
end

local function read()
  local data = read_file()
  set_defaults(data)
  cache_computed_api_backend_settings(data["default_api_backend_settings"])

  return data
end

return read()
