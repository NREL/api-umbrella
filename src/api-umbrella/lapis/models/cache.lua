local db = require "lapis.db"
local iso8601 = require "api-umbrella.utils.iso8601"
local model_ext = require "api-umbrella.utils.model_ext"

local Cache = model_ext.new_class("cache", {
  created_at_timestamp = function(self)
    return iso8601.postgres_to_timestamp(self.created_at)
  end,
}, {
})

Cache.upsert = function(_, id, data, expires_at)
  db.query("INSERT INTO cache(id, data, expires_at) VALUES(?, ?, ?) ON CONFLICT (id) DO UPDATE SET expires_at = EXCLUDED.expires_at, data = EXCLUDED.data", id, db.raw(ngx.ctx.pgmoon:encode_bytea(data)), iso8601.format_postgres(expires_at))
end

return Cache
