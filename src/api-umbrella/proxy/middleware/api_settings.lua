local append_array = require "api-umbrella.utils.append_array"
local config = require "api-umbrella.proxy.models.file_config"
local deep_merge_overwrite_arrays = require "api-umbrella.utils.deep_merge_overwrite_arrays"
local deepcopy = require("pl.tablex").deepcopy
local seq = require "pl.seq"

local re_find = ngx.re.find
local unique = seq.unique

return function(api)
  -- Fetch the default settings
  local settings = deepcopy(config["default_api_backend_settings"])

  -- Merge the base API settings on top.
  if api["settings"] then
    deep_merge_overwrite_arrays(settings, api["settings"])
  end

  -- See if there's any settings for a matching sub-url.
  if api["sub_settings"] then
    local request_method = ngx.ctx.request_method
    local request_uri = ngx.ctx.request_uri
    for _, sub_settings in ipairs(api["sub_settings"]) do
      if (sub_settings["http_method"] == "any" or sub_settings["http_method"] == request_method) and sub_settings["regex"] then
        local find_from, _, find_err = re_find(request_uri, sub_settings["regex"], "ijo")
        if find_from then
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
        elseif find_err then
          ngx.log(ngx.ERR, "regex error: ", find_err)
        end
      end
    end
  end

  return settings
end
