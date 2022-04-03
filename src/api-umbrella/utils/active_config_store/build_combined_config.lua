local append_array = require "api-umbrella.utils.append_array"
local deepcopy = require("pl.tablex").deepcopy
local file_config = require "api-umbrella.proxy.models.file_config"
local int64_to_string = require("api-umbrella.utils.int64").to_string

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
  if published_config and published_config["id"] then
    db_version = int64_to_string(published_config["id"])
  end

  local file_version = file_config["version"]

  local version = (db_version or "") .. ":" .. (file_version or "")

  return {
    api_backends = build_combined_api_backends(published_config),
    website_backends = build_combined_website_backends(published_config),
    db_version = db_version,
    file_version = file_version,
    version = version,
  }
end
