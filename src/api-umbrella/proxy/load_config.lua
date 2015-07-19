local _M = {}

local inspect = require "inspect"
local lyaml = require "lyaml"
local utils = require "api-umbrella.proxy.utils"

local append_array = utils.append_array
local log = ngx.log
local ERR = ngx.ERR

-- lyaml reads YAML null values as a special "LYAML null" object. In our case,
-- we just want to get rid of null values, so recursively walk the YAML config
-- and get rid of any of these special "LYAML null" values.
function nillify_yaml_nulls(table)
  if not table then return end

  for key, value in pairs(table) do
    if (getmetatable(value) or {})._type == "LYAML null" then
      table[key] = nil
    elseif type(value) == "table" then
      table[key] = nillify_yaml_nulls(value)
    end
  end

  return table
end

function _M.parse()
  local f, err = io.open(os.getenv("API_UMBRELLA_CONFIG"), "rb")
  if err then
    return log(ERR, "failed to open config file: ", err)
  end

  local content = f:read("*all")
  f:close()

  local data = lyaml.load(content)
  nillify_yaml_nulls(data)

  local default_hostname
  if data["hosts"] then
    for _, host in ipairs(data["hosts"]) do
      if host["default"] and host["hostname"] then
        default_hostname = host["hostname"]
        break
      end
    end
  end

  data["_default_hostname"] = default_hostname
  local default_hostname = default_hostname or "localhost"

  if data["internal_apis"] then
    for _, api in ipairs(data["internal_apis"]) do
      if api["frontend_host"] == "{{default_hostname}}" then
        api["frontend_host"] = default_hostname
      end
    end
  end

  if data["internal_website_backends"] then
    for _, website in ipairs(data["internal_website_backends"]) do
      if website["frontend_host"] == "{{default_hostname}}" then
        website["frontend_host"] = default_hostname
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
  data["_combined_apis"] = combined_apis
  data["apis"] = nil
  data["internal_apis"] = nil

  local combined_website_backends = {}
  append_array(combined_website_backends, data["internal_website_backends"] or {})
  append_array(combined_website_backends, data["website_backends"] or {})
  data["_combined_website_backends"] = combined_website_backends
  data["website_backends"] = nil
  data["internal_website_backends"] = nil

  return data
end

return _M
