local append_array = require "api-umbrella.utils.append_array"
local deepcopy = require("pl.tablex").deepcopy
local file_config = require("api-umbrella.utils.load_config")()
local int64 = require "api-umbrella.utils.int64"

local int64_from_string = int64.from_string
local int64_to_string = int64.to_string

local function build_combined_api_backends(published_config)
  local api_backends = deepcopy(file_config["_apis"]) or {}

  if published_config and published_config["config"] and published_config["config"]["apis"] then
    append_array(api_backends, published_config["config"]["apis"])
  end

  return api_backends
end

local function build_combined_website_backends(published_config)
  local website_backends = deepcopy(file_config["_website_backends"]) or {}

  if published_config and published_config["config"] and published_config["config"]["website_backends"] then
    append_array(website_backends, published_config["config"]["website_backends"])
  end

  return website_backends
end

return function(published_config)
  local db_version
  local db_version_str
  if published_config and published_config["id"] then
    db_version = published_config["id"]
    db_version_str = int64_to_string(db_version)
  end

  local file_version = file_config["version"]
  local file_version_str
  if file_version then
    file_version_str = tostring(file_version)
  end

  -- We have two separate versions: The file config version (mainly set for the
  -- test environment), and the db config version. We need to come up with a
  -- single, unique version string for Envoy so Envoy can know when the config
  -- changes. So use Szudzik's pairing function to translate the two separate
  -- integers into a single integer value:
  -- https://en.wikipedia.org/wiki/Pairing_function#Other_pairing_functions
  --
  -- Theoretically, this could be any string (we used to concatenate these
  -- together), but our usage of the enovy-control-plane currently requires the
  -- special "snapshot_version" be an integer:
  -- https://github.com/feature-id/envoy-control-plane/blob/9cfe2fb253098932ce2403fc19963e278e57c68c/main.go#L268-L272
  -- The value also doesn't necessarily need to increment, it just needs to be
  -- unique, so that's why a pairing function should work.
  local envoy_version
  if not file_version then
    file_version = 1
  end
  if not db_version then
    db_version = int64_from_string("0")
  end
  if file_version >= db_version then
    envoy_version = file_version * file_version + file_version + db_version
  else
    envoy_version = file_version + db_version * db_version
  end

  return {
    api_backends = build_combined_api_backends(published_config),
    website_backends = build_combined_website_backends(published_config),
    db_version = db_version_str,
    file_version = file_version_str,
    envoy_version = int64_to_string(envoy_version),
  }
end
