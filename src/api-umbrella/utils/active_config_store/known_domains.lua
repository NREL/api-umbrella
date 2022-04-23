local file_config = require("api-umbrella.utils.load_config")()
local psl = require "api-umbrella.utils.psl"

local _M = {}

function _M.build_known_api_domains(api_backends)
  local domains = {}

  if file_config["web"]["default_host"] then
    domains[file_config["web"]["default_host"]] = 1
  end

  if file_config["router"]["web_app_host"] then
    domains[file_config["router"]["web_app_host"]] = 1
  end

  if file_config["hosts"] then
    for _, host in ipairs(file_config["hosts"]) do
      if host and host["hostname"] then
        domains[host["hostname"]] = 1
      end
    end
  end

  if api_backends then
    for _, api_backend in ipairs(api_backends) do
      if api_backend and api_backend["frontend_host"] then
        domains[api_backend["frontend_host"]] = 1
      end
    end
  end

  return domains
end

function _M.build_known_private_suffix_domains(known_api_domains, website_backends)
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

return _M
