local config = require("api-umbrella.utils.load_config")()
local encryptor = require "api-umbrella.utils.encryptor"
local pg_encode_bytea = require("pgmoon").Postgres.encode_bytea
local pg_utils = require "api-umbrella.utils.pg_utils"

pg_utils.db_config["user"] = config["postgresql"]["auto_ssl"]["username"]
pg_utils.db_config["password"] = config["postgresql"]["auto_ssl"]["password"]

local _M = {}

function _M.new()
  return setmetatable({ options = {} }, { __index = _M })
end

function _M.get(_, key)
  local value
  local result, err = pg_utils.query("SELECT * FROM auto_ssl_storage WHERE key = :key AND (expires_at IS NULL or expires_at < NOW())", { key = key })
  if result and result[1] then
    local row = result[1]
    value = encryptor.decrypt(row["value_encrypted"], row["value_encrypted_iv"], key, { base64 = false })
  end

  return value, err
end

function _M.set(_, key, value, options)
  local encrypted, iv = encryptor.encrypt(value, key, { base64 = false })
  local row = {
    key = key,
    value_encrypted = pg_utils.raw(pg_encode_bytea(nil, encrypted)),
    value_encrypted_iv = iv,
  }
  if options and options["exptime"] then
    row["expires_at"] = pg_utils.raw("NOW() + interval " .. pg_utils.escape_literal(options["exptime"] .. " seconds"))
  end

  return pg_utils.query("INSERT INTO auto_ssl_storage (key, value_encrypted, value_encrypted_iv, expires_at) VALUES(:key, :value_encrypted, :value_encrypted_iv, :expires_at) ON CONFLICT (key) DO UPDATE SET value_encrypted = EXCLUDED.value_encrypted, value_encrypted_iv = EXCLUDED.value_encrypted_iv, expires_at = EXCLUDED.expires_at", row)
end

function _M.delete(_, key)
  return pg_utils.delete("auto_ssl_storage", { key = key })
end

function _M.keys_with_suffix(_, suffix)
  local result, err = pg_utils.query("SELECT key FROM auto_ssl_storage WHERE key LIKE '%' || :suffix AND (expires_at IS NULL or expires_at < NOW())", { suffix = pg_utils.escape_like(suffix) })

  local keys = nil
  if not err and result then
    keys = {}
    for _, row in ipairs(result) do
      table.insert(keys, row["key"])
    end
  end

  return keys, err
end

return _M
