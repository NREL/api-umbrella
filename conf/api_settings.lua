local inspect = require "inspect"
local tablex = require "pl.tablex"
local utils = require "utils"

local merge_settings = utils.merge_settings
local deepcopy = tablex.deepcopy

return function(api)
  -- Fetch the default settings
  local settings = deepcopy(config["apiSettings"])

  -- Merge the base API settings on top.
  if api["settings"] then
    merge_settings(settings, api["settings"])
  end

  -- See if there's any settings for a matching sub-url.
  if api["sub_settings"] then
    local request_method = string.lower(ngx.var.request_method)
    local request_uri = ngx.var.request_uri
    for _, sub_settings in ipairs(api["sub_settings"]) do
      if sub_settings["http_method"] == "any" or sub_settings["http_method"] == request_method then
        local match, err = ngx.re.match(request_uri, sub_settings["regex"], "io")
        if match then
          merge_settings(settings, sub_settings["settings"])
          break
        end
      end
    end
  end

  return settings
end
