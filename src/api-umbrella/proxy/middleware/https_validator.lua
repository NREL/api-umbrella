local inspect = require "inspect"
local types = require "pl.types"

local is_empty = types.is_empty

return function(settings, user)
  local protocol = ngx.ctx.protocol
  if protocol == "https" then
    -- https requests are always okay, so continue.
    return nil
  elseif protocol ~= "http" then
    -- If this isn't an http request, then we don't know how to handle it, so
    -- continue.
    return nil
  else
    local mode = settings["require_https"]
    if not mode or mode == "optional" then
      -- Continue if https isn't required.
      return nil
    else
      if mode == "transition_return_error" then
        local transition_start_at = settings["_require_https_transition_start_at"]
        if not user or not user["created_at"] or user["created_at"] < transition_start_at then
          -- If there is no user, or the user existed prior to the HTTPS
          -- transition starting, then continue on, allowing http.
          return nil
        end
      end

      local https_url = "https://" .. ngx.ctx.host
      if config["https_port"] and config["https_port"] ~= 443 then
        https_url = https_url .. ":" .. config["https_port"]
      end
      https_url = https_url .. ngx.ctx.original_request_uri

      return "https_required", {
        httpsUrl = https_url,
      }
    end
  end
end
