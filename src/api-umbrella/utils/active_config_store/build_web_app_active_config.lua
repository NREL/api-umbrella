local build_combined_config = require("api-umbrella.utils.active_config_store.build_combined_config")
local known_domains = require "api-umbrella.utils.active_config_store.known_domains"
local xpcall_error_handler = require "api-umbrella.utils.xpcall_error_handler"

local build_known_api_domains = known_domains.build_known_api_domains
local build_known_private_suffix_domains = known_domains.build_known_private_suffix_domains

return function(published_config)
  local combined_config = build_combined_config(published_config)

  local api_ok, known_api_domains = xpcall(build_known_api_domains, xpcall_error_handler, combined_config["api_backends"])
  if not api_ok then
    ngx.log(ngx.ERR, "failed building known API domains: ", known_api_domains)
    known_api_domains = nil
  end

  local private_ok, known_private_suffix_domains = xpcall(build_known_private_suffix_domains, xpcall_error_handler, known_api_domains, combined_config["website_backends"])
  if not private_ok then
    ngx.log(ngx.ERR, "failed building known API domains: ", known_private_suffix_domains)
    known_private_suffix_domains = nil
  end

  local active_config = {
    known_domains = {
      apis = known_api_domains,
      private_suffixes = known_private_suffix_domains,
    },
    db_version = combined_config["db_version"],
    file_version = combined_config["file_version"],
    envoy_version = combined_config["envoy_version"],
  }

  return active_config
end
