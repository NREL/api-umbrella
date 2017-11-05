local Cache = require "api-umbrella.lapis.models.cache"
local analytics_policy = require "api-umbrella.lapis.policies.analytics_policy"
local capture_errors_json = require("api-umbrella.utils.lapis_helpers").capture_errors_json
local cjson = require("cjson")
local db = require "lapis.db"
local http = require "resty.http"
local interval_lock = require "api-umbrella.utils.interval_lock"
local iso8601 = require "api-umbrella.utils.iso8601"
local json_encode = require "api-umbrella.utils.json_encode"
local lapis_json = require "api-umbrella.utils.lapis_json"

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
    total_users = total_users + month["count"]
  end

  return {
    users_by_month = users_by_month,
    total_users = total_users,
  }
end

local function generate_summary_hits(start_time, end_time)
  local elasticsearch_host = config["elasticsearch"]["hosts"][1]
  local interval = "month"
  local query = {
    query = {
      filtered = {
        query = {
          match_all = {},
        },
        filter = {
          bool = {
            must = {},
            must_not = {},
          },
        },
      },
    },
    sort = {
      { request_at = "desc" },
    },
    aggregations = {},
  }

  table.insert(query["query"]["filtered"]["filter"]["bool"]["must_not"], {
    exists = {
      field = "imported",
    },
  })

  table.insert(query["query"]["filtered"]["filter"]["bool"]["must"], {
    range = {
      request_at = {
        from = start_time,
        to = end_time,
      },
    },
  })

  -- Try to ignore some of the baseline monitoring traffic. Only include
  -- successful responses.
  if config["web"]["analytics_v0_summary_filter"] then
    query["query"]["filtered"]["query"] = {
      query_string = {
        query = config["web"]["analytics_v0_summary_filter"],
      },
    }
  end

  query["aggregations"]["hits_over_time"] = {
    date_histogram = {
      field = "request_at",
      interval = interval,
      time_zone = "America/New_York", -- Time.zone.name,
      min_doc_count = 0,
      extended_bounds = {
        min = start_time,
        max = end_time,
      },
    },
  }
  if config["elasticsearch"]["api_version"] < 2 then
    query["aggregations"]["hits_over_time"]["date_histogram"]["pre_zone_adjust_large_interval"] = true
  end

  -- This query can take a long time to run, so set a long timeout. But since
  -- we're only delivering cached results and refreshing periodically in the
  -- background, this long timeout should be okay.
  query["timeout"] = 20 * 60 .. "s" -- 20 minutes

  query["size"] = 0

  setmetatable(query["query"]["filtered"]["filter"]["bool"]["must_not"], cjson.empty_array_mt)
  setmetatable(query["query"]["filtered"]["filter"]["bool"]["must"], cjson.empty_array_mt)
  setmetatable(query["sort"], cjson.empty_array_mt)
  local httpc = http.new()
  local res, err = httpc:request_uri(elasticsearch_host .. "/_search", {
    method = "POST",
    headers = {
      ["Content-Type"] = "application/json",
    },
    body = json_encode(query),
  })
  local data = cjson.decode(res.body)

  local total_hits = 0
  local hits_by_month = {}
  for _, month in ipairs(data["aggregations"]["hits_over_time"]["buckets"]) do
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
  local end_time = iso8601.format_timestamp(ngx.now())
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

  return lapis_json(self, response_json)
end

return function(app)
  app:get("/api-umbrella/v0/analytics/summary(.:format)", capture_errors_json(_M.summary))
end
