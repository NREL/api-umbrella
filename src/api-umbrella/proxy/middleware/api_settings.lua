local inspect = require "inspect"
local seq = require "pl.seq"
local tablex = require "pl.tablex"
local utils = require "api-umbrella.proxy.utils"

local append_array = utils.append_array
local deep_merge_overwrite_arrays = utils.deep_merge_overwrite_arrays
local deepcopy = tablex.deepcopy
local unique = seq.unique

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
        local match, err = ngx.re.match(request_uri, sub_settings["regex"], "ijo")
        if match then
          local original_required_roles
          if not sub_settings["settings"]["required_roles_override"] then
            original_required_roles = settings["required_roles"]
          end

          deep_merge_overwrite_arrays(settings, sub_settings["settings"])

          if sub_settings["settings"]["required_roles_override"] then
            if not sub_settings["settings"]["required_roles"] then
              settings["required_roles"] = {}
            end
          else
            if original_required_roles then
              settings["required_roles"] = {}
              append_array(settings["required_roles"], original_required_roles)
              append_array(settings["required_roles"], sub_settings["settings"]["required_roles"])
              settings["required_roles"] = unique(settings["required_roles"], true)
            end
          end

          break
        end
      end
    end
  end

  return settings
end
