local settings_keys = {
  "original_api_settings",
  "original_user_settings",
}

local function referer_in_list(referer, allowed_referers)
  for _, allowed_referer in ipairs(allowed_referers) do
    local match = string.find(referer, allowed_referer)
    if match then
      return true
    end
  end

  return false
end

return function(settings)
  -- IE8-9 pseudo CORS support doesn't send Referer headers, only Origin
  -- headers. So fallback to that for checking (this isn't really the same
  -- thing as the referer, though, so this could probably use some
  -- revisiting).
  local referer = ngx.var.http_referer or ngx.var.http_origin;

  -- In most cases, we check the merged "settings" object, but in this case, we
  -- want to check the original API and User IP requirements independently.
  for _, key in ipairs(settings_keys) do
    if settings[key] then
      local allowed_referers = settings[key]["_allowed_referer_matchers"]
      if allowed_referers then
        if not referer or not referer_in_list(referer, allowed_referers) then
          return "api_key_unauthorized"
        end
      end
    end
  end
end
