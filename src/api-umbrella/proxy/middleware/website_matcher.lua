local config = require "api-umbrella.proxy.models.file_config"
local matches_hostname = require "api-umbrella.utils.matches_hostname"

return function(active_config)
  local websites = active_config["website_backends"] or {}
  local default_website
  for _, website in ipairs(websites) do
    if matches_hostname(website["_frontend_host_normalized"], website["_frontend_host_wildcard_regex"]) then
      return website
    elseif website["_frontend_host_normalized"] == config["_default_hostname_normalized"]then
      default_website = website
    end
  end

  -- If a default host exists, only return it if a more specific match wasn't
  -- found.
  if default_website then
    return default_website
  end

  return nil, "not_found"
end
