local model_ext = require "api-umbrella.web-app.utils.model_ext"
local pg_utils = require "api-umbrella.utils.pg_utils"
local time = require "api-umbrella.utils.time"

local Cache = model_ext.new_class("cache", {
  updated_at_timestamp = function(self)
    return time.postgres_to_timestamp(self.updated_at)
  end,
}, {
})

Cache.upsert = function(_, id, data, expires_at)
  pg_utils.query("INSERT INTO cache(id, expires_at, data) VALUES(:id, :expires_at, :data) ON CONFLICT (id) DO UPDATE SET expires_at = EXCLUDED.expires_at, data = EXCLUDED.data", {
    id = id,
    expires_at = time.timestamp_to_iso8601(expires_at),
    data = pg_utils.bytea(data),
  }, { fatal = true })
end

return Cache
