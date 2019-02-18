local AnalyticsSearch = require "api-umbrella.web-app.models.analytics_search"
local Cache = require "api-umbrella.web-app.models.cache"
local analytics_policy = require "api-umbrella.web-app.policies.analytics_policy"
local capture_errors_json = require("api-umbrella.web-app.utils.capture_errors").json
local config = require "api-umbrella.proxy.models.file_config"
local db = require "lapis.db"
local int64_to_json_number = require("api-umbrella.utils.int64").to_json_number
local interval_lock = require "api-umbrella.utils.interval_lock"
local json_encode = require "api-umbrella.utils.json_encode"
local json_response = require "api-umbrella.web-app.utils.json_response"
local time = require "api-umbrella.utils.time"

local _M = {}

local function generate_summary_users(start_time, end_time)
  -- Fetch the user signups by month, trying to remove duplicate signups for
  -- the same e-mail address (each e-mail address only gets counted for the
  -- first month it signed up). Also fill in 0s for missing months of no data.
  local users_by_month = db.query([[
    SELECT extract(year FROM all_months.month) AS year, extract(month FROM all_months.month) AS month, COALESCE(counts_by_month.users_count, 0) AS "count"
    FROM (
      SELECT month
      FROM generate_series(timestamp ?, timestamp ?, interval '1 month') AS month
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
  ]], start_time, end_time)

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

  return {
    hits_by_month = hits_by_month,
    total_hits = total_hits,
  }
end

local function generate_summary()
  local start_time = "2013-07-01T00:00:00"
  local end_time = time.timestamp_to_iso8601(ngx.now())
  local users = generate_summary_users(start_time, end_time)
  local hits = generate_summary_hits(start_time, end_time)

  local response = {
    users_by_month = users["users_by_month"],
    hits_by_month = hits["hits_by_month"],
    total_users = users["total_users"],
    total_hits = hits["total_hits"],
    cached_at = end_time,
  }

  local cache_id = "analytics_summary"
  local response_json = json_encode(response)
  local expires_at = ngx.now() + 60 * 60 * 24 * 2
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
    if cache:created_at_timestamp() < ngx.now() - 60 * 60 * 6 then
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

  return json_response(self, response_json)
end

return function(app)
  app:get("/api-umbrella/v0/analytics/summary(.:format)", capture_errors_json(_M.summary))
end
