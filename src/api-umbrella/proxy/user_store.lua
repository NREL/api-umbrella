local cmsgpack = require "cmsgpack"
local hmac = require "api-umbrella.utils.hmac"
local invert_table = require "api-umbrella.utils.invert_table"
local json_null = require("cjson").null
local lrucache = require "resty.lrucache.pureffi"
local nillify_json_nulls = require "api-umbrella.utils.nillify_json_nulls"
local pg_utils = require "api-umbrella.utils.pg_utils"
local shcache = require "shcache"
local types = require "pl.types"
local utils = require "api-umbrella.proxy.utils"

local cache_computed_settings = utils.cache_computed_settings
local is_empty = types.is_empty

local _M = {}

local function lookup_user(api_key)
  local api_key_hash = hmac(api_key)
  local result, err = pg_utils.query("SELECT * FROM api_users_flattened WHERE api_key_hash = $1", api_key_hash)
  if not result then
    ngx.log(ngx.ERR, "failed to fetch user from database: ", err)
    return nil
  end

  local user = result[1]
  if not user then
    return nil
  end

  -- Invert the array of roles into a hashy table for more optimized
  -- lookups (so we can just check if the key exists, rather than
  -- looping over each value).
  if user["roles"] then
    user["roles"] = invert_table(user["roles"])
  end

  if user["settings"] then
    nillify_json_nulls(user["settings"])
    cache_computed_settings(user["settings"])
  end

  return user
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

  user = shared_cache:load(api_key)
  if user then
    local_cache:set(api_key, user, 2)
  else
    local_cache:set(api_key, EMPTY_DATA, 2)
  end

  return user
end

return _M
