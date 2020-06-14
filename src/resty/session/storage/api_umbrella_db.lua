local db = require "lapis.db"

local _M = {}
_M.__index = _M

function _M.new()
  local self = {}
  return setmetatable(self, _M)
end

function _M.open(_, id)
  local data
  local res = db.query("SELECT data_encrypted FROM sessions WHERE id_hash = ? AND expires_at >= now()", id)
  if res and res[1] and res[1]["data_encrypted"] then
    data = res[1]["data_encrypted"]
  end

  return data
end

function _M.start()
  return true
end

function _M.save(_, id, ttl, data)
  local iv = string.sub(id, 1, 12)

  db.query("INSERT INTO sessions(id_hash, expires_at, data_encrypted, data_encrypted_iv) VALUES(?, now() + interval ?, ?, ?) ON CONFLICT (id_hash) DO UPDATE SET expires_at = EXCLUDED.expires_at, data_encrypted = EXCLUDED.data_encrypted, data_encrypted_iv = EXCLUDED.data_encrypted_iv", id, ttl .. " seconds", db.raw(ngx.ctx.pgmoon:encode_bytea(data)), iv)
  return true
end

function _M.close()
  return true
end

function _M.destroy(_, id)
  db.query("DELETE FROM sessions WHERE id_hash = ?", id)
end

function _M.ttl(_, id, ttl)
  db.query("UPDATE sessions SET expires_at = now() + interval ? WHERE id_hash = ?", ttl .. " seconds", id)
  return true
end

return _M
