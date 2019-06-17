local json_encode = require "api-umbrella.utils.json_encode"
local model_ext = require "api-umbrella.web-app.utils.model_ext"
local pg_utils = require "api-umbrella.utils.pg_utils"
local time = require "api-umbrella.utils.time"

local AnalyticsCache = model_ext.new_class("analytics_cache", {
  updated_at_timestamp = function(self)
    return time.postgres_to_timestamp(self.updated_at)
  end,
}, {
})

AnalyticsCache.find_by_id_data = function(_, id_data)
  -- Hash the unique JSON data that makes up this row's identifier into a
  -- sha256 fingerprint for the actual primary key.
  --
  -- Since the underlying JSON data (representing the fully query being cached)
  -- may exceed the allowed size for an index ("index row size X exceeds
  -- maximum X for index" error), we can't use the actual JSON data as the
  -- primary key, and must hash it.
  --
  -- We rely on PostgreSQL's hashing with JSONB, which ensures consistent
  -- hashing of JSON, regardless of key ordering or spacing (eg
  -- `{"a": 1, "b": 2}` and `{"b":2,"a":1}` both get hashed the same).
  return pg_utils.query("SELECT id FROM analytics_cache WHERE id = encode(digest(:id_data::jsonb::text, 'sha256'), 'hex')", {
    id_data = json_encode(id_data),
  }, { fatal = true })[1]
end

AnalyticsCache.upsert = function(_, id_data, data, expires_at)
  return pg_utils.query("INSERT INTO analytics_cache(id, id_data, data, expires_at) VALUES(encode(digest(:id_data::jsonb::text, 'sha256'), 'hex'), :id_data, :data, :expires_at) ON CONFLICT (id) DO UPDATE SET id_data = EXCLUDED.id_data, data = EXCLUDED.data, expires_at = EXCLUDED.expires_at RETURNING id", {
    id_data = json_encode(id_data),
    data = json_encode(data),
    expires_at = time.timestamp_to_iso8601(expires_at),
  }, { fatal = true })[1]
end

return AnalyticsCache
