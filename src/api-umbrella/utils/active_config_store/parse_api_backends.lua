local stable_object_hash = require "api-umbrella.utils.stable_object_hash"
local cache_computed_api_backend = require "api-umbrella.utils.active_config_store.cache_computed_api_backend"
local cache_computed_api_backend_settings = require "api-umbrella.utils.active_config_store.cache_computed_api_backend_settings"
local cache_computed_api_backend_sub_settings = require "api-umbrella.utils.active_config_store.cache_computed_api_backend_sub_settings"
local xpcall_error_handler = require "api-umbrella.utils.xpcall_error_handler"

local function parse_api(api)
  if not api["id"] then
    api["id"] = stable_object_hash(api)
  end

  cache_computed_api_backend(api)
  cache_computed_api_backend_settings(api["settings"])
  cache_computed_api_backend_sub_settings(api["sub_settings"])
end

return function(api_backends)
  for _, api in ipairs(api_backends) do
    local ok, err = xpcall(parse_api, xpcall_error_handler, api)
    if not ok then
      ngx.log(ngx.ERR, "failed parsing API config: ", err)
    end
  end
end
