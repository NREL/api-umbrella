local aes = require "resty.aes"
local config = require "api-umbrella.proxy.models.file_config"
local mongo = require "api-umbrella.utils.mongo"
local path = require "pl.path"
local resty_random = require "resty.random"
local str = require "resty.string"

local _M = {}
local ENCRYPTION_SECRET = ""

local function create_index()
  local _, err = mongo.create("system.indexes", {
    ns = config["mongodb"]["_database"] .. ".ssl_certs",
    key = {
      expire_at = 1,
    },
    name = "expire_at",
    expireAfterSeconds = 0,
    background = true,
  })
  if err then
    ngx.log(ngx.ERR, "failed to create mongodb expire_at index: ", err)
  end
end

function _M.new()
  return setmetatable({ options = {} }, { __index = _M })
end

function _M.setup()
  local file, err = io.open(path.join(config["etc_dir"], "auto-ssl/encryption_secret"), "r")
  if err then
    ngx.log(ngx.ERR, "auto-ssl: failed to open encryption_secret file: ", err)
    return false, err
  end

  ENCRYPTION_SECRET = string.gsub(file:read("*all"), "%s*$", "")
  file:close()
end

function _M.setup_worker()
  ngx.timer.at(0, create_index)
end

function _M.get(_, key)
  local res, err = mongo.first("ssl_certs", {
    query = {
      _id = key
    },
  })

  if res then
    if res["encrypted_value"] and res["encryption_iv"] then
      local aes_instance = assert(aes:new(ENCRYPTION_SECRET, nil, aes.cipher(256, "cbc"), { iv = res["encryption_iv"] }))
      res = aes_instance:decrypt(ngx.decode_base64(res["encrypted_value"]))
      if not res then
        ngx.log(ngx.ERR, "auto-ssl: decryption failed: ", (tostring(err) or ""))
        err = "decryption failed"
      end
    else
      ngx.log(ngx.ERR, "auto-ssl: database doesn't contain expected encrypted values")
    end
  end

  return res, err
end

function _M.set(_, key, value, options)
  local strong_random = resty_random.bytes(8, true)
  while strong_random == nil do
    strong_random = resty_random.bytes(8, true)
  end
  strong_random = str.to_hex(strong_random)

  local aes_instance = assert(aes:new(ENCRYPTION_SECRET, nil, aes.cipher(256, "cbc"), { iv = strong_random }))
  local encrypted = assert(ngx.encode_base64(aes_instance:encrypt(value)))

  local doc = {
    _id = key,
    encryption_iv = strong_random,
    encrypted_value = encrypted,
  }
  if options and options["exptime"] then
    doc["expire_at"] = { ["$date"] = { ["$numberLong"] = tostring((ngx.now() + options["exptime"]) * 1000) } }
  end

  return mongo.update("ssl_certs", key, doc)
end

function _M.delete(_, key)
  return mongo.delete("ssl_certs", key)
end

function _M.keys_with_suffix(_, suffix)
  local results, err = mongo.find("ssl_certs", {
    -- FIXME: Should fix Mongo adapter to return unlimited results, rather than
    -- Mora's default pagination.
    limit = 10000,
    query = {
      _id = {
        ["$regex"] = suffix .. "$"
      }
    },
  })

  local keys = nil
  if not err and results then
    keys = {}
    for _, result in ipairs(results) do
      table.insert(keys, result["_id"])
    end
  end

  return keys, err
end

return _M
