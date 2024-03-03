local AnalyticsSearch = require "api-umbrella.web-app.models.analytics_search"
local Cache = require "api-umbrella.web-app.models.cache"
local analytics_policy = require "api-umbrella.web-app.policies.analytics_policy"
local capture_errors_json = require("api-umbrella.web-app.utils.capture_errors").json
local config = require("api-umbrella.utils.load_config")()
local icu_date = require "icu-date-ffi"
local int64_to_json_number = require("api-umbrella.utils.int64").to_json_number
local interval_lock = require "api-umbrella.utils.interval_lock"
local json_decode = require("cjson").decode
local json_encode = require "api-umbrella.utils.json_encode"
local json_response = require "api-umbrella.web-app.utils.json_response"
local pg_utils = require "api-umbrella.utils.pg_utils"
local respond_to = require "api-umbrella.web-app.utils.respond_to"
local time = require "api-umbrella.utils.time"

local _M = {}

local function generate_organization_summary(start_time, end_time, recent_start_time, filters)
  local cache_id = "analytics_summary:organization:" .. start_time .. ":" .. end_time .. ":" .. recent_start_time .. ":" .. ngx.md5(json_encode(filters))
  local cache = Cache:find(cache_id)
  if cache then
    ngx.log(ngx.NOTICE, "Using cached analytics response for " .. cache_id)
    return json_decode(cache.data)
  end
  ngx.log(ngx.NOTICE, "Fetching new analytics response for " .. cache_id)

  local search = AnalyticsSearch.factory(config["analytics"]["adapter"])
  search:set_start_time(start_time)
  search:set_end_time(end_time)
  search:set_interval("month")
  search:filter_exclude_imported()
  search:aggregate_by_interval_for_summary()
  search:aggregate_by_cardinality("user_id.hash")
  search:aggregate_by_response_time_average()
  if config["web"]["analytics_v0_summary_filter"] then
    search:set_search_query_string(config["web"]["analytics_v0_summary_filter"])
  end
  search:set_timeout(20 * 60) -- 20 minutes
  search:set_permission_scope(filters)

  local aggregate_sql = [[
    SELECT jsonb_build_object(
      'hits', jsonb_build_object(
        :interval_name, jsonb_agg(jsonb_build_array(interval_totals.interval_date, COALESCE(interval_totals.hit_count, 0))),
        'total', SUM(interval_totals.hit_count)
      ),
      'active_api_keys', jsonb_build_object(
        :interval_name, jsonb_agg(jsonb_build_array(interval_totals.interval_date, COALESCE(array_length(interval_totals.unique_user_ids, 1), 0))),
        'total', (
          SELECT COUNT(DISTINCT user_ids.id)
          FROM unnest(array_accum(interval_totals.unique_user_ids)) AS user_ids(id)
        )
      ),
      'average_response_times', jsonb_build_object(
        :interval_name, jsonb_agg(jsonb_build_array(interval_totals.interval_date, interval_totals.response_time_average)),
        'average', ROUND(SUM(CASE WHEN interval_totals.response_time_average IS NOT NULL AND interval_totals.hit_count IS NOT NULL THEN interval_totals.response_time_average * interval_totals.hit_count END) / SUM(CASE WHEN interval_totals.response_time_average IS NOT NULL AND interval_totals.hit_count IS NOT NULL THEN interval_totals.hit_count END))
      )
    ) AS response
    FROM (
      SELECT
        interval_date,
        hit_count,
        response_time_average,
        (
          SELECT array_agg(DISTINCT user_id)
          FROM unnest(interval_agg.user_ids) AS user_id
            LEFT JOIN api_users ON user_id = api_users.id
          WHERE user_id IS NOT NULL AND api_users.disabled_at IS NULL
        ) AS unique_user_ids
      FROM (
        SELECT
          substring(bucket->>'key_as_string' from 1 for :date_key_length) AS interval_date,
          SUM((bucket->>'doc_count')::bigint) AS hit_count,
          array_accum(unique_user_ids) AS user_ids,
          ROUND(SUM(CASE WHEN bucket->'response_time_average'->>'value' IS NOT NULL AND bucket->>'doc_count' IS NOT NULL THEN (bucket->'response_time_average'->>'value')::numeric * (bucket->>'doc_count')::bigint END) / SUM(CASE WHEN bucket->'response_time_average'->>'value' IS NOT NULL AND bucket->>'doc_count' IS NOT NULL THEN (bucket->>'doc_count')::bigint END)) AS response_time_average
        FROM analytics_cache
          CROSS JOIN LATERAL jsonb_array_elements(data->'aggregations'->'hits_over_time'->'buckets') AS bucket
        WHERE id IN :ids
        GROUP BY interval_date
        ORDER BY interval_date
      ) AS interval_agg
    ) AS interval_totals
  ]]

  -- Expire the monthly data in 3 months. While the historical data shouldn't
  -- really change, the API scopes may change (which are part of
  -- the cache key), so for that reason, don't keep old data around
  -- indefinitely. But since we update the expires_at timestamp on rows that
  -- are still being accessed, this should ensure we only expire unused data.
  local expires_at = ngx.now() + 60 * 60 * 24 * 30 * 3
  local analytics_cache_ids = search:cache_interval_results(expires_at)
  local response = pg_utils.query(aggregate_sql, {
    ids = pg_utils.list(analytics_cache_ids),
    interval_name = "monthly",
    date_key_length = 7,
  }, { fatal = true })[1]["response"]

  search:set_start_time(recent_start_time)
  search:set_interval("day")
  search:aggregate_by_interval_for_summary()
  expires_at = ngx.now() + 60 * 60 * 24 * 30 -- 30 days
  local recent_analytics_cache_ids = search:cache_interval_results(expires_at)
  local recent_response = pg_utils.query(aggregate_sql, {
    ids = pg_utils.list(recent_analytics_cache_ids),
    interval_name = "daily",
    date_key_length = 10,
  }, { fatal = true })[1]["response"]

  response["hits"]["recent"] = recent_response["hits"]
  response["active_api_keys"]["recent"] = recent_response["active_api_keys"]
  response["average_response_times"]["recent"] = recent_response["average_response_times"]

  local response_json = json_encode(response)
  expires_at = ngx.now() + 60 * 60 * 24 * 2 -- 2 days
  Cache:upsert(cache_id, response_json, expires_at)

  return response
end

local function generate_production_apis_summary(start_time, end_time, recent_start_time)
  local data = {
    organizations = {},
  }
  local counts = pg_utils.query([[
    SELECT COUNT(DISTINCT api_backends.organization_name) AS organization_count,
      COUNT(DISTINCT api_backends.id) AS api_backend_count,
      COUNT(DISTINCT api_backend_url_matches.id) AS api_backend_url_match_count
    FROM api_backends
      LEFT JOIN api_backend_url_matches ON api_backends.id = api_backend_url_matches.api_backend_id
    WHERE api_backends.status_description = 'Production'
  ]], nil, { fatal = true })
  data["organization_count"] = int64_to_json_number(counts[1]["organization_count"])
  data["api_backend_count"] = int64_to_json_number(counts[1]["api_backend_count"])
  data["api_backend_url_match_count"] = int64_to_json_number(counts[1]["api_backend_url_match_count"])

  local all_filters = {
    condition = "OR",
    rules = {},
  }

  local organizations = pg_utils.query([[
    SELECT api_backends.organization_name,
      COUNT(DISTINCT api_backends.id) AS api_backend_count,
      COUNT(DISTINCT api_backend_url_matches.id) AS api_backend_url_match_count,
      json_agg(json_build_object('frontend_host', api_backends.frontend_host, 'frontend_prefix', api_backend_url_matches.frontend_prefix)) AS url_prefixes
    FROM api_backends
      LEFT JOIN api_backend_url_matches ON api_backends.id = api_backend_url_matches.api_backend_id
    WHERE api_backends.status_description = 'Production'
    GROUP BY api_backends.organization_name
    ORDER BY api_backends.organization_name
  ]], nil, { fatal = true })
  for _, organization in ipairs(organizations) do
    local filters = {
      condition = "OR",
      rules = {},
    }
    for _, url_prefix in ipairs(organization["url_prefixes"]) do
      local rule = {
        condition = "AND",
        rules = {
          {
            field = "request_host",
            operator = "equal",
            value = string.lower(url_prefix["frontend_host"]),
          },
          {
            field = "request_path",
            operator = "begins_with",
            value = string.lower(url_prefix["frontend_prefix"]),
          },
        },
      }
      table.insert(filters["rules"], rule)
      table.insert(all_filters["rules"], rule)
    end

    ngx.log(ngx.NOTICE, 'Fetching analytics for organization "' .. organization["organization_name"] .. '"')
    local organization_data = generate_organization_summary(start_time, end_time, recent_start_time, filters)
    organization_data["name"] = organization["organization_name"]
    organization_data["api_backend_count"] = int64_to_json_number(organization["api_backend_count"])
    organization_data["api_backend_url_match_count"] = int64_to_json_number(organization["api_backend_url_match_count"])
    table.insert(data["organizations"], organization_data)
  end

  ngx.log(ngx.NOTICE, "Fetching analytics for all organizations")
  local all_data = generate_organization_summary(start_time, end_time, recent_start_time, all_filters)
  data["all"] = all_data

  return data
end

local function generate_summary()
  local date_tz = icu_date.new({
    zone_id = config["analytics"]["timezone"],
  })
  local format_iso8601 = icu_date.formats.iso8601()

  date_tz:parse(format_iso8601, config["web"]["analytics_v0_summary_start_time"])
  date_tz:set_time_zone_id(config["analytics"]["timezone"])
  local start_time = date_tz:format(format_iso8601)
  local start_time_ms = date_tz:get_millis()

  if config["web"]["analytics_v0_summary_end_time"] then
    date_tz:parse(format_iso8601, config["web"]["analytics_v0_summary_end_time"])
    date_tz:set_time_zone_id(config["analytics"]["timezone"])
  else
    date_tz:set_millis(ngx.now() * 1000)
    date_tz:add(icu_date.fields.DATE, -1)
    date_tz:set(icu_date.fields.HOUR_OF_DAY, 23)
    date_tz:set(icu_date.fields.MINUTE, 59)
    date_tz:set(icu_date.fields.SECOND, 59)
    date_tz:set(icu_date.fields.MILLISECOND, 999)
  end
  local end_time = date_tz:format(format_iso8601)
  local end_time_ms = date_tz:get_millis()

  date_tz:add(icu_date.fields.DATE, -29)
  date_tz:set(icu_date.fields.HOUR_OF_DAY, 0)
  date_tz:set(icu_date.fields.MINUTE, 0)
  date_tz:set(icu_date.fields.SECOND, 0)
  date_tz:set(icu_date.fields.MILLISECOND, 0)
  local recent_start_time = date_tz:format(format_iso8601)

  local response = {
    production_apis = generate_production_apis_summary(start_time, end_time, recent_start_time),
    start_time = time.timestamp_ms_to_iso8601(start_time_ms),
    end_time = time.timestamp_ms_to_iso8601(end_time_ms),
    timezone = date_tz:get_time_zone_id(),
  }

  response["cached_at"] = time.timestamp_to_iso8601(ngx.now())

  local cache_id = "analytics_summary"
  local response_json = json_encode(response)
  local expires_at = ngx.now() + 60 * 60 * 24 * 2 -- 2 days
  Cache:upsert(cache_id, response_json, expires_at)

  return response_json
end

function _M.summary(self)
  analytics_policy.authorize_summary()

  local response_json

  -- Try to fetch the summary data out of the cache.
  local cache = Cache:find("analytics_summary")
  if cache then
    self.res.headers["X-Cache"] = "HIT"
    response_json = cache.data

    -- If the cached data is older than 6 hours, then go ahead and an re-fetch
    -- and cache the data asynchronously in the background. Since this takes a
    -- while to generate, we want ensure we always have valid cached data (so
    -- users don't get a super slow response and we don't overwhelm the server
    -- when it's uncached).
    if cache:updated_at_timestamp() < ngx.now() - 60 * 60 * 6 then
      ngx.timer.at(0, function()
        -- Ensure only one pre-seed is happening at a time (at least per
        -- server).
        interval_lock.mutex_exec("preseed_analytics_summary_cache", generate_summary)
      end)
    end
  else
    -- If it's not cached, generate it now.
    self.res.headers["X-Cache"] = "MISS"
    response_json = generate_summary()
  end

  self.res.headers["Access-Control-Allow-Origin"] = "*"
  return json_response(self, response_json)
end

return function(app)
  app:match("/api-umbrella/v0/analytics/summary(.:format)", respond_to({ GET = capture_errors_json(_M.summary) }))
end
