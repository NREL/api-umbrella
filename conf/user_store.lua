local _M = {}

local inspect = require "inspect"
local cmsgpack = require "cmsgpack"
local cjson = require "cjson"
local lrucache = require "resty.lrucache.pureffi"
local shcache = require "shcache"
local std_table = require "std.table"
local types = require "pl.types"
local utils = require "utils"
local http = require "resty.http"

local clone_select = std_table.clone_select
local invert = std_table.invert
local is_empty = types.is_empty
local get_packed = utils.get_packed

local function lookup_user(api_key)
  local httpc = http.new()
  local res, err = httpc:request_uri("http://127.0.0.1:8181/docs/api_umbrella/" .. config["mongodb"]["database"] .. "/api_users", {
    query = {
      extended_json = "true",
      limit = 1,
      query = cjson.encode({
        api_key = api_key,
      }),
    },
  })

  if not err and res.body then
    local response = cjson.decode(res.body)
    if response and response["data"] and response["data"][1] then
      local raw = response["data"][1]

      local user = clone_select(raw, {
        "disabled_at",
        "throttle_by_ip",
      })

      -- Ensure IDs get stored as strings, even if Mongo ObjectIds are in use.
      user["id"] = tostring(raw["_id"])

      -- Invert the array of roles into a hashy table for more optimized
      -- lookups (so we can just check if the key exists, rather than
      -- looping over each value).
      if raw["roles"] then
        user["roles"] = invert(raw["roles"])
      end

      if user["throttle_by_ip"] == false then
        user["throttle_by_ip"] = nil
      end

      if raw["settings"] then
        user["settings"] = clone_select(raw["settings"], {
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
    decode = cmsgpack.decode,
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
    local_cache:set(api_key, user)
  else
    local_cache:set(api_key, EMPTY_DATA)
  end

  return user
end

return _M
