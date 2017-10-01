local db = require "lapis.db"
local escape_regex = require "api-umbrella.utils.escape_regex"
local iso8601 = require "api-umbrella.utils.iso8601"
local split = require("ngx.re").split
local hmac = require "api-umbrella.utils.hmac"

local now = ngx.now
local decode_base64 = ngx.decode_base64
local encode_base64 = ngx.encode_base64

local _M = {}
_M.__index = _M

function _M.new(config)
  local self = {
    encode = config.encoder.encode,
    decode = config.encoder.decode,
    delimiter = config.cookie.delimiter,
  }

  return setmetatable(self, _M)
end

function _M:open(cookie, lifetime)
  local parts = split(cookie, escape_regex(self.delimiter))
  if parts and parts[1] and parts[2] and parts[3] then
    local id = self.decode(parts[1])
    local expires = tonumber(parts[2])
    local hmac_data = self.decode(parts[3])

    local data
    local res = db.query("SELECT data_encrypted FROM sessions WHERE id_hash = ? AND expires_at > now()", hmac(id))
    if res and res[1] and res[1]["data_encrypted"] then
      data = decode_base64(res[1]["data_encrypted"])
      db.query("UPDATE sessions SET expires_at = now() + interval ? WHERE id_hash = ?", lifetime .. " seconds", hmac(id))
    end

    return id, expires, data, hmac_data
  end

  return nil, "invalid"
end

function _M:save(id, expires, data, hmac_data)
  local iv = string.sub(id, 1, 12)
  local ttl = expires - now()
  if ttl <= 0 then
    return nil, "expired"
  end

  db.query("INSERT INTO sessions(id_hash, expires_at, data_encrypted, data_encrypted_iv) VALUES(?, ?, ?, ?) ON CONFLICT (id_hash) DO UPDATE SET expires_at = EXCLUDED.expires_at, data_encrypted = EXCLUDED.data_encrypted, data_encrypted_iv = EXCLUDED.data_encrypted_iv", hmac(id), iso8601.format_postgres(expires), encode_base64(data), iv)
  return table.concat({ self.encode(id), expires, self.encode(hmac_data) }, self.delimiter)
end

function _M.destroy(_, id)
  db.query("DELETE FROM sessions WHERE id_hash = ?", hmac(id))
end

return _M
