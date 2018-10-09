local user_store = require "api-umbrella.proxy.user_store"
local types = require "pl.types"
local stringx = require "pl.stringx"
local plutils = require "pl.utils"

local startswith = stringx.startswith
local split = plutils.split
local get_user = user_store.get
local is_empty = types.is_empty

local function resolve_api_key()
  local api_key_methods = config["gatekeeper"]["api_key_methods"]
  local key = {key_value="", key_type="", idp=nil}

  -- The api_key variable is a dictionary compose by three elements, the key_value which stores
  -- the api_key value or the user token value, the key_type field in where is stored
  -- the type of key that was provided by the user, it value could be an api_key or a token, Finally
  -- the idp field indicates, if the api-backend have an IdP registred for the token validation
  -- The validation process is made for all the api_key_methods (except basicAuthUsername)
  -- declared in the configuration file, checking if the user sends an api_key or token
  -- Only the header and get_param methods are supported by the token validation.
  for _, method in ipairs(api_key_methods) do
    if method == "header" and ngx.ctx.http_x_api_key then
      key.key_value = ngx.ctx.http_x_api_key
      key.key_type = "api_key"
    elseif method == "fiware-oauth2" and ngx.ctx.http_authorization and startswith(ngx.ctx.http_authorization, "Bearer ") then
      key.key_value = split(ngx.ctx.http_authorization)[2]
      key.key_type = "token"
    elseif method == "getParam" and ngx.ctx.arg_api_key then
      key.key_value = ngx.ctx.arg_api_key
      key.key_type = "api_key"
    elseif method == "basicAuthUsername" and ngx.ctx.remote_user then
      key.key_value = ngx.ctx.remote_user
      key.key_type = "api_key"
    end

    if not is_empty(key["key_value"]) then
      break
    end
  end

  -- Store the api key for logging.
  ngx.ctx.api_key = key["key_value"]

  return key
end

return function(settings)
  -- Find the API key in the header, query string, or HTTP auth.
  local api_key = resolve_api_key()

  -- Find if and IdP was set
  if settings and settings["ext_auth_allowed"] and config["gatekeeper"]["default_idp"] then
    api_key.idp=config["gatekeeper"]["default_idp"]
    api_key.app_id = settings["idp_app_id"]
    api_key.mode = settings["idp_mode"]
  end

  if is_empty(api_key["key_value"]) then
    if settings and settings["disable_api_key"] then
      return nil
    else
      return nil, "api_key_missing"
    end
  end

  -- Check if the user is trying to use an access token when external IDP is not allowed
  if api_key["key_type"] == "token" and (not settings or (not settings["disable_api_key"] and not settings["ext_auth_allowed"])) then
    return nil, "token_not_supported"
  end

  -- Look for the api key in the user database.
  local user = get_user(api_key)
  if not user then
    return nil, "api_key_invalid"
  end

  -- Store the api key on the user object for easier access (the user object
  -- doesn't contain it directly, to save memory storage in the lookup table).
  user["api_key"] = api_key["key_value"]

  -- Store user details for logging.
  ngx.ctx.user_id = user["id"]
  ngx.ctx.user_email = user["email"]
  ngx.ctx.user_registration_source = user["registration_source"]

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
