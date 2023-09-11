local config = require("api-umbrella.utils.load_config")()
local deepcopy = require("pl.tablex").deepcopy

local re_find = ngx.re.find

return function(ngx_ctx, api)
  local settings

  -- See if there's any settings for a matching sub-url.
  if api["sub_settings"] then
    local request_method = ngx_ctx.request_method
    local request_uri = ngx_ctx.request_uri
    for _, sub_settings in ipairs(api["sub_settings"]) do
      if (sub_settings["http_method"] == "any" or sub_settings["http_method"] == request_method) and sub_settings["regex"] then
        local find_from, _, find_err = re_find(request_uri, sub_settings["regex"], "ijo")
        if find_from then
          settings = sub_settings["settings"]
          break
        elseif find_err then
          ngx.log(ngx.ERR, "regex error: ", find_err)
        end
      end
    end
  end

  if not settings then
    if api["settings"] then
      -- Use the API's global settings.
      settings = api["settings"]
    else
      -- Use the default global settings if no other more specific settings are
      -- available.
      settings = config["_default_api_backend_settings"]
    end
  end

  return deepcopy(settings)
end
