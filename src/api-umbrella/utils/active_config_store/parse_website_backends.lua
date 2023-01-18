local set_hostname_regex = require "api-umbrella.utils.active_config_store.set_hostname_regex"
local stable_object_hash = require "api-umbrella.utils.stable_object_hash"
local xpcall_error_handler = require "api-umbrella.utils.xpcall_error_handler"

local function parse_website_backend(website_backend)
  if not website_backend["id"] then
    website_backend["id"] = stable_object_hash(website_backend)
  end

  if website_backend["frontend_host"] then
    set_hostname_regex(website_backend, "frontend_host")
  end

  website_backend["_backend_host"] = website_backend["backend_host"]
  if not website_backend["_backend_host"] then
    website_backend["_backend_host"] = website_backend["server_host"]
  end
end

local function sort_by_frontend_host_length(a, b)
  return string.len(tostring(a["frontend_host"])) > string.len(tostring(b["frontend_host"]))
end

return function(website_backends)
  for _, website_backend in ipairs(website_backends) do
    local ok, err = xpcall(parse_website_backend, xpcall_error_handler, website_backend)
    if not ok then
      ngx.log(ngx.ERR, "failed parsing website backend config: ", err)
    end
  end

  table.sort(website_backends, sort_by_frontend_host_length)
end
