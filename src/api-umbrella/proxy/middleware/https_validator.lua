local httpsify_current_url = require "api-umbrella.utils.httpsify_current_url"

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
    if settings["redirect_https"] then
      return "redirect_https"
    end

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

      local https_url = httpsify_current_url()
      return "https_required", {
        https_url = https_url,
        httpsUrl = https_url,
      }
    end
  end
end
