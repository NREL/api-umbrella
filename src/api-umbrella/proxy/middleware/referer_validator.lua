local re_match = ngx.re.match

local settings_keys = {
  "original_api_settings",
  "original_user_settings",
}

local function referer_in_list(referer, allowed_referers)
  for _, allowed_referer in ipairs(allowed_referers) do
    local match, match_err = re_match(referer, allowed_referer, "ijo")
    if match then
      return true
    elseif match_err then
      ngx.log(ngx.ERR, "regex error: ", match_err)
    end
  end

  return false
end

return function(settings)
  -- Support falling back to matching the Origin header if the Referer header
  -- isn't present.
  --
  -- Note that the Origin header is different, since it excludes the path
  -- portion of the URL, so the matchers we use in this case eliminate the path
  -- requirements from the allowed referers. So while this makes Origin
  -- matching slightly looser, this should still provide sanity checking on the
  -- domain, while providing compatibility for situations where the Referer
  -- header is not present.
  --
  -- The Referer header might be missing in a few different cases:
  --
  -- - Users with browser plugins that strip the Referer for privacy reasons
  --   (but these typically leave Origin).
  -- - Corporate proxies that strip Referer for similar reasons.
  -- - IE8-9 pseudo CORS support, which sends the Origin header, but no
  --   Referer.
  local referer = ngx.var.http_referer
  local origin_mode = false
  if not referer then
    referer = ngx.var.http_origin
    origin_mode = true
  end

  -- In most cases, we check the merged "settings" object, but in this case, we
  -- want to check the original API and User IP requirements independently.
  for _, key in ipairs(settings_keys) do
    if settings[key] then
      local allowed_referers
      if origin_mode then
        allowed_referers = settings[key]["_allowed_referer_origin_regexes"]
      else
        allowed_referers = settings[key]["_allowed_referer_regexes"]
      end

      if allowed_referers then
        if not referer or not referer_in_list(referer, allowed_referers) then
          return "api_key_unauthorized"
        end
      end
    end
  end
end
