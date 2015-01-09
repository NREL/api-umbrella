local user_store = require "user_store"

local resolve_api_key = function()
  local api_key_methods = config["gatekeeper"]["api_key_methods"]
  local api_key

  for _, method in ipairs(api_key_methods) do
    if method == "header" then
      api_key = ngx.var.http_x_api_key
    elseif method == "getParam" then
      api_key = ngx.var.arg_api_key
    elseif method == "basicAuthUsername" then
      api_key = ngx.var.remote_user
    end

    if api_key then
      break
    end
  end

  return api_key
end

return function(settings)
  local api_key = resolve_api_key()

  if not api_key then
    return nil, "api_key_missing"
  end

  local user = user_store.get(api_key)

  if not user then
    return nil, "api_key_invalid"
  end

  user["api_key"] = api_key

  if user["disabled_at"] then
    return nil, "api_key_disabled"
  end

  return user
end
