local cjson = require "cjson"
local deep_merge_overwrite_arrays = require "api-umbrella.utils.deep_merge_overwrite_arrays"
local lyaml = require "lyaml"
local writefile = require("pl.utils").writefile

local json_decode = cjson.decode
local json_null = cjson.null
local yaml_dump = lyaml.dump
local yaml_null = lyaml.null

local function json_nulls_to_yaml_nulls(table)
  if not table then return end

  for key, value in pairs(table) do
    if value == json_null then
      table[key] = yaml_null
    elseif type(value) == "table" then
      table[key] = json_nulls_to_yaml_nulls(value)
    end
  end

  return table
end

return function()
  local vcap_services = os.getenv("VCAP_SERVICES")
  if not vcap_services then
    io.stderr:write("'VCAP_SERVICES' environment variable not defined\n")
    os.exit(1)
  end

  local config_service_name = os.getenv("API_UMBRELLA_CONFIG_VCAP_SERVICE_NAME")
  if not config_service_name then
    io.stderr:write("'API_UMBRELLA_CONFIG_VCAP_SERVICE_NAME' environment variable not defined\n")
    os.exit(1)
  end

  local config = {}

  -- Fetch Cloud Foundry service information from the VCAP_SERVICES environment
  -- variable.
  local vcap_services_data = json_decode(vcap_services)

  -- Find our secret configuration (via a user provided service), and merge that
  -- on top of the existing API Umbrella config.
  local found_config_service = false
  for _, service in ipairs(vcap_services_data["user-provided"]) do
    if service["name"] == config_service_name then
      found_config_service = true
      deep_merge_overwrite_arrays(config, json_nulls_to_yaml_nulls(service["credentials"]))
    end
  end

  if not found_config_service then
    io.stderr:write("Did not find the '" .. config_service_name .. "' service in VCAP_SERVICES\n")
    os.exit(1)
  end

  local config_path = os.getenv("API_UMBRELLA_CONFIG") or "/etc/api-umbrella/api-umbrella.yml"
  writefile(config_path, yaml_dump({ config }))
end
