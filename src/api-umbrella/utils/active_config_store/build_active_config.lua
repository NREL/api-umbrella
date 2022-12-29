local build_combined_config = require("api-umbrella.utils.active_config_store.build_combined_config")
local parse_api_backends = require("api-umbrella.utils.active_config_store.parse_api_backends")
local parse_website_backends = require("api-umbrella.utils.active_config_store.parse_website_backends")

return function(published_config)
  local combined_config = build_combined_config(published_config)

  local active_config = {
    api_backends = combined_config["api_backends"],
    website_backends = combined_config["website_backends"],
    db_version = combined_config["db_version"],
    file_version = combined_config["file_version"],
    version = combined_config["version"],
  }

  parse_api_backends(active_config["api_backends"])
  parse_website_backends(active_config["website_backends"])

  return active_config
end
