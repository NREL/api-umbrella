local user_store = require "api-umbrella.proxy.user_store"
local types = require "pl.types"

local get_user = user_store.get
local is_empty = types.is_empty

local function resolve_api_key()
  local api_key_methods = config["gatekeeper"]["api_key_methods"]
  local api_key

  for _, method in ipairs(api_key_methods) do
    if method == "header" then
      api_key = ngx.ctx.http_x_api_key
    elseif method == "getParam" then
      api_key = ngx.ctx.arg_api_key
    elseif method == "basicAuthUsername" then
      api_key = ngx.ctx.remote_user
    end

    if not is_empty(api_key) then
      break
    end
  end

  -- Store the api key for logging.
  ngx.ctx.api_key = api_key

  return api_key
end

return function(settings)
  -- Find the API key in the header, query string, or HTTP auth.
  local api_key = resolve_api_key()
  if is_empty(api_key) then
    if settings and settings["disable_api_key"] then
      return nil
    else
      return nil, "api_key_missing"
    end
  end

  -- Look for the api key in the user database.
  local user = get_user(api_key)
  if not user then
    return nil, "api_key_invalid"
  end

  -- Store the api key on the user object for easier access (the user object
  -- doesn't contain it directly, to save memory storage in the lookup table).
  user["api_key"] = api_key

  -- Store user details for logging.
  ngx.ctx.user_id = user["id"]

  -- Check to make sure the user isn't disabled.
  if user["disabled_at"] then
    return nil, "api_key_disabled"
  end

  -- Check if this API requires the user's API key be verified in some fashion
  -- (for example, if they must verify their e-mail address during signup).
  if settings and settings["api_key_verification_level"] then
    local verification_level = settings["api_key_verification_level"]
    if verification_level == "required_email" then
      if not user["email_verified"] then
        return nil, "api_key_unverified"
      end
    elseif verification_level == "transition_email" then
      local transition_start_at = settings["_api_key_verification_transition_start_at"]
      if user["created_at"] and user["created_at"] >= transition_start_at and not user["email_verified"] then
        return nil, "api_key_unverified"
      end
    end
  end

  return user
end
