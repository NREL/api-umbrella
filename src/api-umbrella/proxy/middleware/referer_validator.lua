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
  -- doesn't match.
  --
  -- Note that the Origin header is different, since it excludes the path
  -- portion of the URL, so the matchers we use in this case eliminate the path
  -- requirements from the allowed referers. So while this makes Origin
  -- matching slightly looser, this should still provide sanity checking on the
  -- domain, while providing compatibility for situations where the Referer
  -- header is not present or is changed.
  --
  -- The Referer header might be missing or forged in a few different cases:
  --
  -- - Users with browser plugins that strip or change the Referer for privacy
  --   reasons (but these typically leave Origin).
  -- - Proxies that strip Referer for similar reasons (eg, Privoxy in "block"
  --   or "forge" mode:
  --   http://www.privoxy.org/user-manual/actions-file.html#HIDE-REFERRER).
  -- - IE8-9 pseudo CORS support, which sends the Origin header, but no
  --   Referer.
  local referer = ngx.var.http_referer
  local origin = ngx.var.http_origin

  -- In most cases, we check the merged "settings" object, but in this case, we
  -- want to check the original API and User IP requirements independently.
  for _, key in ipairs(settings_keys) do
    if settings[key] then
      -- If there are any referrer requirements.
      local allowed_referers = settings[key]["_allowed_referer_regexes"]
      if allowed_referers then
        -- If a referrer is missing or not in the list of allowed referrers,
        -- then this request may be rejected.
        if not referer or not referer_in_list(referer, allowed_referers) then
          -- Before rejecting the request, fall back to checking the origin
          -- header to account for situations where the Referer header is
          -- stripped or replaced with the API domain's home page.
          local allowed_origins = settings[key]["_allowed_referer_origin_regexes"]
          if not origin or not referer_in_list(origin, allowed_origins) then
            return "api_key_unauthorized"
          end
        end
      end
    end
  end
end
