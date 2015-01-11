local inspect = require "inspect"
local iputils = require "resty.iputils"

local ip_in_cidrs = iputils.ip_in_cidrs

local settings_keys = {
  "original_api_settings",
  "original_user_settings",
}

return function(settings, user)
  local ip = ngx.ctx.remote_addr

  -- In most cases, we check the merged "settings" object, but in this case, we
  -- want to check the original API and User IP requirements independently.
  for _, key in ipairs(settings_keys) do
    if settings[key] then
      local allowed_cidrs = settings[key]["_allowed_cidrs"]
      if allowed_cidrs then
        -- Match based on the allowed CIDR ranges.
        if not ip or not ip_in_cidrs(ip, allowed_cidrs) then
          return "api_key_unauthorized"
        end
      end
    end
  end
end
