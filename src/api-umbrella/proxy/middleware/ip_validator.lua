local cidr = require "libcidr-ffi"

local settings_keys = {
  "original_api_settings",
  "original_user_settings",
}

local function ip_in_cidrs(ip, allowed_ips)
  local ip_cidr = cidr.from_str(ip)

  for _, allowed_ip in ipairs(allowed_ips) do
    local allowed_cidr = cidr.from_str(allowed_ip)
    if cidr.contains(allowed_cidr, ip_cidr) then
      return true
    end
  end

  return false
end

return function(ngx_ctx, settings)
  local ip = ngx_ctx.remote_addr

  -- In most cases, we check the merged "settings" object, but in this case, we
  -- want to check the original API and User IP requirements independently.
  for _, key in ipairs(settings_keys) do
    if settings[key] then
      local allowed_ips = settings[key]["_allowed_ips"]
      if allowed_ips then
        -- Match based on the allowed CIDR ranges.
        if not ip or not ip_in_cidrs(ip, allowed_ips) then
          return "api_key_unauthorized"
        end
      end
    end
  end
end
