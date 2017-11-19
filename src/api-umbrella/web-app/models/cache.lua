local db = require "lapis.db"
local model_ext = require "api-umbrella.web-app.utils.model_ext"
local time = require "api-umbrella.utils.time"

local Cache = model_ext.new_class("cache", {
  created_at_timestamp = function(self)
    return time.postgres_to_timestamp(self.created_at)
  end,
}, {
})

Cache.upsert = function(_, id, data, expires_at)
  db.query("INSERT INTO cache(id, data, expires_at) VALUES(?, ?, ?) ON CONFLICT (id) DO UPDATE SET expires_at = EXCLUDED.expires_at, data = EXCLUDED.data", id, db.raw(ngx.ctx.pgmoon:encode_bytea(data)), time.timestamp_to_iso8601(expires_at))
end

return Cache
