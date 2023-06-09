local httpsify_current_url = require "api-umbrella.utils.httpsify_current_url"

-- The "https_validator" middleware takes care of most HTTPS requirements
-- earlier in the request lifecycle. But for APIs using the "transition" mode
-- (where existing API keys are allowed to continue using HTTP, but new API
-- keys must use HTTPS), we must handle this in a separate middleware that is
-- executed later, after we've fetched the API key user information.
return function(ngx_ctx, settings, user)
  local protocol = ngx_ctx.protocol
  if protocol == "http" then
    local mode = settings["require_https"]
    if mode == "transition_return_error" then
      local transition_start_at = settings["_require_https_transition_start_at"]

      -- If the user was created after the HTTPS transition date, then require
      -- HTTPS. Otherwise, continue allowing HTTP access for older API keys.
      if user and user["created_at"] and user["created_at"] >= transition_start_at then
        local https_url = httpsify_current_url(ngx_ctx)
        return "https_required", {
          https_url = https_url,
          httpsUrl = https_url,
        }
      end
    end
  end

  return nil
end
