local _M = {}

local cmsgpack = require "cmsgpack"
local cjson = require "cjson"
local invert_table = require "api-umbrella.utils.invert_table"
local lrucache = require "resty.lrucache.pureffi"
local mongo = require "api-umbrella.utils.mongo"
local shcache = require "shcache"
local types = require "pl.types"
local utils = require "api-umbrella.proxy.utils"
local pep = require "api-umbrella.utils.pep"

local cache_computed_settings = utils.cache_computed_settings
local is_empty = types.is_empty

local function lookup_user(api_key)
  local raw_user
  local db_err
  local pep_err

  -- Checking the field of api_key ["key_type"], if the key_type is api_key
  -- the api_key value is checked in the database and retrieve the user information
  -- else if the key_type is token, the token is checked using PEP Proxy and
  -- the user information is retrieved
  if not api_key["key_type"] or api_key["key_type"] == "api_key" then
    raw_user, db_err = mongo.first("api_users", {
      query = {
        api_key = api_key["key_value"],
      },
    })
  elseif api_key["key_type"] == "token" then
    raw_user, pep_err = pep.first(config["gatekeeper"]["pep_host"],config["gatekeeper"]["pep_port"],api_key["key_value"])
  end
  if pep_err then
    ngx.log(ngx.ERR, "failed to autenticate , status code:", pep_err)
  elseif db_err then
    ngx.log(ngx.ERR, "failed to fetch user from mongodb", db_err)
  elseif raw_user then
    local user = utils.pick_where_present(raw_user, {
      "created_at",
      "disabled_at",
      "email",
      "email_verified",
      "registration_source",
      "roles",
      "settings",
      "throttle_by_ip",
    })

    -- Ensure IDs get stored as strings, even if Mongo ObjectIds are in use.
    if raw_user["_id"] and raw_user["_id"]["$oid"] then
      user["id"] = raw_user["_id"]["$oid"]
    elseif raw_user.Nick_Name then
        user["id"] = raw_user.Nick_Name
        if not raw_user.Email then
            user["email"] = raw_user.Nick_Name
        else
            user["email"] = raw_user.Email
        end
    else
        user["id"] = raw_user["_id"]
    end
    -- If the validation was made using a token, the Nick_Name associate to the token
    -- is assigned to the id attribute of the user
    if raw_user.Nick_Name then
      user["id"] = raw_user.Nick_Name
    end

    -- Invert the array of roles into a hashy table for more optimized
    -- lookups (so we can just check if the key exists, rather than
    -- looping over each value).
    -- Moreover, in case that the user information have been retrieved using a token validation,
    -- the roles associated with the token are stored in user ["roles"]
    if user["roles"] then
      user["roles"] = invert_table(user["roles"])
    elseif raw_user.Roles then
      user["roles"] = invert_table(raw_user.Roles)
    end

    if user["created_at"] and user["created_at"]["$date"] then
      user["created_at"] = user["created_at"]["$date"]
    end

    if user["settings"] and user["settings"] ~= cjson.null then
      user["settings"] = utils.pick_where_present(user["settings"], {
        "allowed_ips",
        "allowed_referers",
        "rate_limit_mode",
        "rate_limits",
      })

      if is_empty(user["settings"]) then
        user["settings"] = nil
      else
        cache_computed_settings(user["settings"])
      end
    end

    return user
  end
end

local local_cache = lrucache.new(500)

local EMPTY_DATA = "_EMPTY_"

function _M.get(api_key)
  if not config["gatekeeper"]["api_key_cache"] then
    return lookup_user(api_key)
  end

  local user = local_cache:get(api_key)
  if user then
    if user == EMPTY_DATA then
      return nil
    else
      return user
    end
  end

  local shared_cache, err = shcache:new(ngx.shared.api_users, {
    encode = cmsgpack.pack,
    decode = cmsgpack.unpack,
    external_lookup = lookup_user,
    external_lookup_arg = api_key,
  }, {
    positive_ttl = 0,
    negative_ttl = 0,
  })

  if err then
    ngx.log(ngx.ERR, "failed to initialize shared cache for users: ", err)
    return nil
  end

  user = shared_cache:load(api_key["key_value"])
  if user then
    local_cache:set(api_key["key_value"], user, 2)
  else
    local_cache:set(api_key["key_value"], EMPTY_DATA, 2)
  end

  return user
end

return _M