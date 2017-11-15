local AnalyticsSearch = require "api-umbrella.lapis.models.analytics_search"
local analytics_policy = require "api-umbrella.lapis.policies.analytics_policy"
local array_last = require "api-umbrella.utils.array_last"
local capture_errors_json = require("api-umbrella.utils.lapis_helpers").capture_errors_json
local cjson = require("cjson")
local csv = require "api-umbrella.lapis.utils.csv"
local formatted_interval_time = require "api-umbrella.lapis.utils.formatted_interval_time"
local lapis_json = require "api-umbrella.utils.lapis_json"
local number_with_delimiter = require "api-umbrella.lapis.utils.number_with_delimiter"
local round = require "api-umbrella.utils.round"
local t = require("resty.gettext").gettext
local time = require "api-umbrella.utils.time"

local gsub = ngx.re.gsub

local _M = {}

local function strip_api_key_from_query(query)
  local stripped
  if query then
    stripped = gsub(query, [[\bapi_key=?[^&]*(&|$)]], "", "ijo")
    stripped = gsub(stripped, [[&$]], "", "jo")
  end

  return stripped
end

local function sanitized_full_url(row)
  local url = row["request_scheme"] .. "://" .. row["request_host"] .. row["request_path"]
  if row["request_url_query"] then
    url = url .. "?" .. strip_api_key_from_query(row["request_url_query"])
  end

  return url
end

local function sanitized_url_path_and_query(row)
  local url = row["request_path"]
  if row["request_url_query"] then
    url = url .. "?" .. strip_api_key_from_query(row["request_url_query"])
  end

  return url
end

local function hits_over_time(interval, aggregations)
  local rows = {}
  if aggregations and aggregations["hits_over_time"] then
    for _, bucket in ipairs(aggregations["hits_over_time"]["buckets"]) do
      table.insert(rows, {
        c = {
          {
            v = bucket["key"],
            f = formatted_interval_time(interval, bucket["key"]),
          },
          {
            v = bucket["doc_count"],
            f = number_with_delimiter(bucket["doc_count"]),
          },
        }
      })
    end
  end

  return rows
end

local function aggregation_result(aggregations, name)
  local buckets = {}
  local top_buckets = aggregations["top_" .. name]["buckets"]
  local with_value_count = aggregations["value_count_" .. name]["value"]
  local missing_count = aggregations["missing_" .. name]["doc_count"]

  local other_hits = with_value_count
  for _, bucket in ipairs(top_buckets) do
    other_hits = other_hits - bucket["doc_count"]

    table.insert(buckets, {
      key = bucket["key"],
      count = bucket["doc_count"],
    })
  end

  if missing_count > 0 then
    local last_bucket = array_last(buckets)
    if #buckets < 10 or missing_count >= last_bucket["count"] then
      table.insert(buckets, {
        key = t("Missing / Unknown"),
        count = missing_count,
      })
    end
  end

  local total = with_value_count + missing_count
  for _, bucket in ipairs(buckets) do
    bucket["percent"] = round((bucket["count"] / total) * 100)
  end

  if other_hits > 0 then
    table.insert(buckets, {
      key = t("Other"),
      count = other_hits,
    })
  end

  return buckets
end

function _M.search(self)
  local search = AnalyticsSearch.factory(config["analytics"]["adapter"], {
    start_time = self.params["start_at"],
    end_time = self.params["end_at"],
    interval = self.params["interval"],
  })
  search:set_permission_scope(analytics_policy.authorized_query_scope(self.current_admin))
  search:filter_by_time_range()
  search:set_search_query_string(self.params["search"])
  search:set_search_filters(self.params["query"])
  search:aggregate_by_interval()
  search:aggregate_by_users(10)
  search:aggregate_by_request_ip(10)
  search:aggregate_by_response_time_average()

  local raw_results = search:fetch_results()
  local response = {
    stats = {
      total_hits = raw_results["hits"]["total"],
      total_users = raw_results["aggregations"]["unique_user_email"]["value"],
      total_ips = raw_results["aggregations"]["unique_request_ip"]["value"],
      average_response_time = raw_results["aggregations"]["response_time_average"]["value"],
    },
    hits_over_time = hits_over_time(search.interval, raw_results["aggregations"]),
    aggregations = {
      users = aggregation_result(raw_results["aggregations"], "user_email"),
      ips = aggregation_result(raw_results["aggregations"], "request_ip"),
    },
  }
  setmetatable(response["hits_over_time"], cjson.empty_array_mt)
  setmetatable(response["aggregations"]["users"], cjson.empty_array_mt)
  setmetatable(response["aggregations"]["ips"], cjson.empty_array_mt)
  return lapis_json(self, response)
end

function _M.logs(self)
  local offset = tonumber(self.params["start"]) or 0
  local limit = tonumber(self.params["length"]) or 0
  if self.params["format"] == "csv" then
    limit = 500
  end

  local search = AnalyticsSearch.factory(config["analytics"]["adapter"], {
    start_time = self.params["start_at"],
    end_time = self.params["end_at"],
    interval = self.params["interval"],
  })
  search:set_permission_scope(analytics_policy.authorized_query_scope(self.current_admin))
  search:filter_by_time_range()
  search:set_search_query_string(self.params["search"])
  search:set_search_filters(self.params["query"])
  search:set_offset(offset)
  search:set_limit(limit)

  if self.params["format"] == "csv" then
    csv.set_response_headers(self, "api_logs (" .. os.date("!%Y-%m-%d", ngx.now()) .. ").csv")

    ngx.say(csv.row_to_csv({
      "Time",
      "Method",
      "Host",
      "URL",
      "User",
      "IP Address",
      "Country",
      "State",
      "City",
      "Status",
      "Reason Denied",
      "Response Time",
      "Content Type",
      "Accept Encoding",
      "User Agent",
    }))
    ngx.flush(true)

    search:fetch_results_bulk(function(hits)
      for _, hit in ipairs(hits) do
        local row = hit["_source"]
        ngx.say(csv.row_to_csv({
          time.elasticsearch_to_csv(row["request_at"]),
          row["request_method"],
          row["request_host"],
          sanitized_full_url(row),
          row["user_email"],
          row["request_ip"],
          row["request_ip_country"],
          row["request_ip_region"],
          row["request_ip_city"],
          row["response_status"],
          row["gatekeeper_denied_code"],
          row["response_time"],
          row["response_content_type"],
          row["request_accept_encoding"],
          row["request_user_agent"],
          row["request_user_agent_family"],
          row["request_user_agent_type"],
          row["request_referer"],
          row["request_origin"],
        }))
      end
      ngx.flush(true)
    end)

    return { layout = false }
  else
    local raw_results = search:fetch_results()
    local response = {
      draw = tonumber(self.params["draw"]),
      recordsTotal = raw_results["hits"]["total"],
      recordsFiltered = raw_results["hits"]["total"],
      data = {}
    }

    for _, hit in ipairs(raw_results["hits"]["hits"]) do
      local row = hit["_source"]
      row["api_key"] = nil
      row["_type"] = nil
      row["_score"] = nil
      row["_index"] = nil
      row["request_url"] = sanitized_url_path_and_query(row)
      row["request_url_query"] = strip_api_key_from_query(row["request_url_query"])
      if row["request_query"] then
        row["request_query"]["api_key"] = nil
      end

      table.insert(response["data"], row)
    end

    setmetatable(response["data"], cjson.empty_array_mt)
    return lapis_json(self, response)
  end
end

function _M.users(self)
end

function _M.map(self)
  local search = AnalyticsSearch.factory(config["analytics"]["adapter"], {
    start_time = self.params["start_at"],
    end_time = self.params["end_at"],
    interval = self.params["interval"],
  })
  search:set_permission_scope(analytics_policy.authorized_query_scope(self.current_admin))
  search:filter_by_time_range()
  search:set_search_query_string(self.params["search"])
  search:set_search_filters(self.params["query"])
  search:aggregate_by_region(self.params["region"])

  local raw_results = search:fetch_results()

  if self.params["format"] == "csv" then
  else
    local response = {
      region_field = search.body["aggregations"]["regions"]["terms"]["field"],
      regions = {},
      map_regions = {},
      map_breadcrumbs = {},
    }
    setmetatable(response["regions"], cjson.empty_array_mt)
    setmetatable(response["map_regions"], cjson.empty_array_mt)
    setmetatable(response["map_breadcrumbs"], cjson.empty_array_mt)
    return lapis_json(self, response)
  end
end

return function(app)
  app:get("/admin/stats/search(.:format)", capture_errors_json(_M.search))
  app:get("/admin/stats/logs(.:format)", capture_errors_json(_M.logs))
  app:post("/admin/stats/logs(.:format)", capture_errors_json(_M.logs))
  app:get("/admin/stats/users(.:format)", capture_errors_json(_M.users))
  app:get("/admin/stats/map(.:format)", capture_errors_json(_M.map))
end
