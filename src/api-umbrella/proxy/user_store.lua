local _M = {}

local inspect = require "inspect"
local cmsgpack = require "cmsgpack"
local cjson = require "cjson"
local lrucache = require "resty.lrucache.pureffi"
local shcache = require "shcache"
local std_table = require "std.table"
local types = require "pl.types"
local utils = require "api-umbrella.proxy.utils"
local http = require "resty.http"

local cache_computed_settings = utils.cache_computed_settings
local clone_select = std_table.clone_select
local invert = std_table.invert
local is_empty = types.is_empty
local get_packed = utils.get_packed

local function lookup_user(api_key)
  local httpc = http.new()
  local res, err = httpc:request_uri("http://127.0.0.1:8181/docs/api_umbrella/" .. config["mongodb"]["_database"] .. "/api_users", {
    query = {
      extended_json = "true",
      limit = 1,
      query = cjson.encode({
        api_key = api_key,
      }),
    },
  })

  if err then
    ngx.log(ngx.ERR, "failed to fetch user from mongodb: ", err)
  elseif res.body then
    local response = cjson.decode(res.body)
    if response and response["data"] and response["data"][1] then
      local raw = response["data"][1]
      local user = utils.pick_where_present(raw, {
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
      if raw["_id"] and raw["_id"]["$oid"] then
        user["id"] = raw["_id"]["$oid"]
      else
        user["id"] = raw["_id"]
      end

      -- Invert the array of roles into a hashy table for more optimized
      -- lookups (so we can just check if the key exists, rather than
      -- looping over each value).
      if user["roles"] then
        user["roles"] = invert(user["roles"])
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
end

local local_cache = lrucache.new(500)

local EMPTY_DATA = "_EMPTY_"

function _M.get(api_key)
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

  local user, from_cache = shared_cache:load(api_key)
  if user then
    local_cache:set(api_key, user, 2)
  else
    local_cache:set(api_key, EMPTY_DATA, 2)
  end

  return user
end

return _M
