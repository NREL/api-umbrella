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

AnalyticsCache.id_datas_exists = function(_, id_datas)
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
  local sql = [[
    WITH cache_ids AS (
      SELECT encode(digest(id_data::text, 'sha256'), 'hex') AS id, id_data
      FROM jsonb_array_elements(:id_datas) AS t (id_data)
    )
    SELECT cache_ids.id, cache_ids.id_data, (analytics_cache.id IS NOT NULL) AS cache_exists
    FROM cache_ids
    LEFT JOIN analytics_cache ON analytics_cache.id = cache_ids.id
  ]]
  return pg_utils.query(sql, {
    id_datas = json_encode(id_datas),
  }, { fatal = true })
end

AnalyticsCache.upsert = function(_, id_data, data, expires_at)
  return pg_utils.query("INSERT INTO analytics_cache(id, id_data, data, expires_at) VALUES(encode(digest(:id_data::jsonb::text, 'sha256'), 'hex'), :id_data, :data, :expires_at) ON CONFLICT (id) DO UPDATE SET id_data = EXCLUDED.id_data, data = EXCLUDED.data, expires_at = EXCLUDED.expires_at RETURNING id", {
    id_data = json_encode(id_data),
    data = json_encode(data),
    expires_at = time.timestamp_to_iso8601(expires_at),
  }, { fatal = true })[1]
end

return AnalyticsCache
