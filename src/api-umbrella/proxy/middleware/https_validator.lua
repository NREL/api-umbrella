local httpsify_current_url = require "api-umbrella.utils.httpsify_current_url"

return function(ngx_ctx, settings)
  local protocol = ngx_ctx.protocol
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
    elseif mode == "transition_return_error" and ngx_ctx.api_key then
      -- If this API is transitioning to HTTPS, then defer the HTTPS checks to
      -- the https_transition_user_validator middleware that will be checked
      -- later (since we need the API key's create date for this logic).
      return nil
    end
  end

  local https_url = httpsify_current_url(ngx_ctx)
  return "https_required", {
    https_url = https_url,
    httpsUrl = https_url,
  }
end
