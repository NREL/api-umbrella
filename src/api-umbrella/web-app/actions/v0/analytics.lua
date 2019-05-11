local AnalyticsSearch = require "api-umbrella.web-app.models.analytics_search"
local Cache = require "api-umbrella.web-app.models.cache"
local analytics_policy = require "api-umbrella.web-app.policies.analytics_policy"
local capture_errors_json = require("api-umbrella.web-app.utils.capture_errors").json
local config = require "api-umbrella.proxy.models.file_config"
local icu_date = require "icu-date"
local int64_to_json_number = require("api-umbrella.utils.int64").to_json_number
local interval_lock = require "api-umbrella.utils.interval_lock"
local json_decode = require("cjson").decode
local json_encode = require "api-umbrella.utils.json_encode"
local json_response = require "api-umbrella.web-app.utils.json_response"
local pg_utils = require "api-umbrella.utils.pg_utils"

local _M = {}

local function generate_summary_users(start_time, end_time)
  -- Fetch the user signups by month, trying to remove duplicate signups for
  -- the same e-mail address (each e-mail address only gets counted for the
  -- first month it signed up). Also fill in 0s for missing months of no data.
  local users_by_month = pg_utils.query([[
    SELECT extract(year FROM all_months.month) AS year, extract(month FROM all_months.month) AS month, COALESCE(counts_by_month.users_count, 0) AS "count"
    FROM (
      SELECT month
      FROM generate_series(timestamp :start_time, timestamp :end_time, interval '1 month') AS month
    ) AS all_months
    LEFT JOIN (
      SELECT date_trunc('month', first_created_at) as created_at_month, COUNT(email) AS users_count
      FROM (
        SELECT email, MIN(created_at) AS first_created_at
        FROM api_users
        WHERE imported != TRUE
          AND disabled_at IS NULL
        GROUP BY email
      ) AS unique_users
      GROUP BY created_at_month
    ) AS counts_by_month ON all_months.month = counts_by_month.created_at_month
    ORDER BY all_months.month
  ]], {
    start_time = start_time,
    end_time = end_time,
  }, { fatal = true })

  local total_users = 0
  for _, month in ipairs(users_by_month) do
    month["count"] = int64_to_json_number(month["count"])
    total_users = total_users + month["count"]
  end

  return {
    users_by_month = users_by_month,
    total_users = total_users,
  }
end

local function generate_summary_hits(start_time, end_time)
  local cache_id = "analytics_summary:hits:" .. start_time .. ":" .. end_time
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
  search:aggregate_by_interval()

  -- Try to ignore some of the baseline monitoring traffic. Only include
  -- successful responses.
  if config["web"]["analytics_v0_summary_filter"] then
    search:set_search_query_string(config["web"]["analytics_v0_summary_filter"])
  end

  -- This query can take a long time to run, so set a long timeout. But since
  -- we're only delivering cached results and refreshing periodically in the
  -- background, this long timeout should be okay.
  search:set_timeout(20 * 60) -- 20 minutes

  local results = search:fetch_results()

  local total_hits = 0
  local hits_by_month = {}
  for _, month in ipairs(results["aggregations"]["hits_over_time"]["buckets"]) do
    table.insert(hits_by_month, {
      year = tonumber(string.sub(month["key_as_string"], 1, 4)),
      month = tonumber(string.sub(month["key_as_string"], 6, 7)),
      count = month["doc_count"],
    })

    total_hits = total_hits + month["doc_count"]
  end

  local response = {
    hits_by_month = hits_by_month,
    total_hits = total_hits,
  }

  local response_json = json_encode(response)
  local expires_at = ngx.now() + 60 * 60 * 24 * 2 -- 2 days
  Cache:upsert(cache_id, response_json, expires_at)

  return response
end

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
  search:aggregate_by_cardinality("user_id")
  search:aggregate_by_response_time_average()
  if config["web"]["analytics_v0_summary_filter"] then
    search:set_search_query_string(config["web"]["analytics_v0_summary_filter"])
  end
  search:set_timeout(20 * 60) -- 20 minutes
  search:set_permission_scope(filters)

  local results = search:fetch_results()

  local hits_monthly = {}
  local active_api_keys_monthly = {}
  local average_response_times_monthly = {}
  for _, month_data in ipairs(results["aggregations"]["hits_over_time"]["buckets"]) do
    local key = string.sub(month_data["key_as_string"], 1, 7)
    table.insert(hits_monthly, { key, month_data["doc_count"] })
    table.insert(active_api_keys_monthly, { key, month_data["unique_user_id"]["value"] })
    table.insert(average_response_times_monthly, { key, month_data["response_time_average"]["value"] })
  end

  search:set_start_time(recent_start_time)
  search:set_interval("day")
  search:aggregate_by_interval_for_summary()
  local recent_results = search:fetch_results()

  local recent_hits_daily = {}
  local recent_active_api_keys_daily = {}
  local recent_average_response_times_daily = {}
  for _, day_data in ipairs(recent_results["aggregations"]["hits_over_time"]["buckets"]) do
    local key = string.sub(day_data["key_as_string"], 1, 10)
    table.insert(recent_hits_daily, { key, day_data["doc_count"] })
    table.insert(recent_active_api_keys_daily, { key, day_data["unique_user_id"]["value"] })
    table.insert(recent_average_response_times_daily, { key, day_data["response_time_average"]["value"] })
  end

  local response = {
    hits = {
      monthly = hits_monthly,
      total = results["hits"]["_total_value"],
      recent = {
        daily = recent_hits_daily,
        total = recent_results["hits"]["_total_value"],
      },
    },
    active_api_keys = {
      monthly = active_api_keys_monthly,
      total = results["aggregations"]["unique_user_id"]["value"],
      recent = {
        daily = recent_active_api_keys_daily,
        total = recent_results["aggregations"]["unique_user_id"]["value"],
      },
    },
    average_response_times = {
      monthly = average_response_times_monthly,
      average = results["aggregations"]["response_time_average"]["value"],
      recent = {
        daily = recent_average_response_times_daily,
        average = recent_results["aggregations"]["response_time_average"]["value"],
      },
    },
  }

  local response_json = json_encode(response)
  local expires_at = ngx.now() + 60 * 60 * 24 * 2 -- 2 days
  Cache:upsert(cache_id, response_json, expires_at)

  return response
end

local function generate_production_apis_summary(start_time, end_time, recent_start_time)
  local data = {
    organizations = {},
  }
  local counts = pg_utils.query([[SELECT COUNT(DISTINCT api_backends.organization_name) AS organization_count,
      COUNT(DISTINCT api_backends.id) AS api_backend_count,
      COUNT(DISTINCT api_backend_url_matches.id) AS api_backend_url_match_count
    FROM api_backends
      LEFT JOIN api_backend_url_matches ON api_backends.id = api_backend_url_matches.api_backend_id
    WHERE api_backends.status_description = 'Production']], nil, { fatal = true })
  data["organization_count"] = int64_to_json_number(counts[1]["organization_count"])
  data["api_backend_count"] = int64_to_json_number(counts[1]["api_backend_count"])
  data["api_backend_url_match_count"] = int64_to_json_number(counts[1]["api_backend_url_match_count"])

  local all_filters = {
    condition = "OR",
    rules = {},
  }

  local organizations = pg_utils.query([[SELECT api_backends.organization_name,
      json_agg(json_build_object('frontend_host', api_backends.frontend_host, 'frontend_prefix', api_backend_url_matches.frontend_prefix)) AS url_prefixes
    FROM api_backends
      LEFT JOIN api_backend_url_matches ON api_backends.id = api_backend_url_matches.api_backend_id
    WHERE api_backends.status_description = 'Production'
    GROUP BY api_backends.organization_name
    ORDER BY api_backends.organization_name]], nil, { fatal = true })
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

  date_tz:set(icu_date.fields.YEAR, 2013)
  date_tz:set(icu_date.fields.MONTH, 6)
  date_tz:set(icu_date.fields.DATE, 1)
  date_tz:set(icu_date.fields.HOUR_OF_DAY, 0)
  date_tz:set(icu_date.fields.MINUTE, 0)
  date_tz:set(icu_date.fields.SECOND, 0)
  date_tz:set(icu_date.fields.MILLISECOND, 0)
  local start_time = date_tz:format(format_iso8601)

  local now_ms = ngx.now() * 1000
  date_tz:set_millis(now_ms)
  date_tz:add(icu_date.fields.DATE, -1)
  date_tz:set(icu_date.fields.HOUR_OF_DAY, 23)
  date_tz:set(icu_date.fields.MINUTE, 59)
  date_tz:set(icu_date.fields.SECOND, 59)
  date_tz:set(icu_date.fields.MILLISECOND, 999)
  local end_time = date_tz:format(format_iso8601)

  date_tz:set_millis(now_ms)
  date_tz:add(icu_date.fields.DATE, -30)
  date_tz:set(icu_date.fields.HOUR_OF_DAY, 0)
  date_tz:set(icu_date.fields.MINUTE, 0)
  date_tz:set(icu_date.fields.SECOND, 0)
  date_tz:set(icu_date.fields.MILLISECOND, 0)
  local recent_start_time = date_tz:format(format_iso8601)

  local users = generate_summary_users(start_time, end_time)
  local hits = generate_summary_hits(start_time, end_time)

  local response = {
    users_by_month = users["users_by_month"],
    hits_by_month = hits["hits_by_month"],
    total_users = users["total_users"],
    total_hits = hits["total_hits"],
    production_apis = generate_production_apis_summary(start_time, end_time, recent_start_time),
    start_time = start_time,
    end_time = end_time,
  }

  date_tz:set_millis(ngx.now() * 1000)
  response["cached_at"] = date_tz:format(format_iso8601)

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
  app:get("/api-umbrella/v0/analytics/summary(.:format)", capture_errors_json(_M.summary))
end
