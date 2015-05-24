local inspect = require "inspect"
local tablex = require "pl.tablex"
local utils = require "utils"

local deep_merge_overwrite_arrays = utils.deep_merge_overwrite_arrays
local deepcopy = tablex.deepcopy

return function(api)
  -- Fetch the default settings
  local settings = deepcopy(config["apiSettings"])

  -- Merge the base API settings on top.
  if api["settings"] then
    deep_merge_overwrite_arrays(settings, api["settings"])
  end

  -- See if there's any settings for a matching sub-url.
  if api["sub_settings"] then
    local request_method = ngx.ctx.request_method
    local request_uri = ngx.ctx.request_uri
    for _, sub_settings in ipairs(api["sub_settings"]) do
      if sub_settings["http_method"] == "any" or sub_settings["http_method"] == request_method then
        local match, err = ngx.re.match(request_uri, sub_settings["regex"], "io")
        if match then
          deep_merge_overwrite_arrays(settings, sub_settings["settings"])
          break
        end
      end
    end
  end

  return settings
end
