local AnalyticsSearch = require "api-umbrella.lapis.models.analytics_search"
local ApiUser = require "api-umbrella.lapis.models.api_user"
local analytics_policy = require "api-umbrella.lapis.policies.analytics_policy"
local array_last = require "api-umbrella.utils.array_last"
local capture_errors_json = require("api-umbrella.utils.lapis_helpers").capture_errors_json
local cjson = require("cjson")
local countries = require "api-umbrella.lapis.utils.countries"
local csv = require "api-umbrella.lapis.utils.csv"
local db = require "lapis.db"
local formatted_interval_time = require "api-umbrella.lapis.utils.formatted_interval_time"
local json_null = require("cjson").null
local lapis_datatables = require "api-umbrella.utils.lapis_datatables"
local lapis_json = require "api-umbrella.utils.lapis_json"
local number_with_delimiter = require "api-umbrella.lapis.utils.number_with_delimiter"
local round = require "api-umbrella.utils.round"
local t = require("resty.gettext").gettext
local table_sub = require("pl.tablex").sub
local time = require "api-umbrella.utils.time"

local null = ngx.null
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

local function region_id(current_region, code)
  if current_region == "US" then
    return "US-" .. code
  else
    return code
  end
end

local function region_name(current_region, code)
  local name = code
  if current_region == "world" then
    country = countries.countries[code]
    if country then
      name = country
    end
  elseif current_region and ngx.re.match(current_region, "^[A-Z]{2}$") then
    subdivisions = countries.subdivisions[current_region]
    if subdivisions then
      subdivision = subdivisions[code]
      if subdivision then
        name = subdivision
      end
    end
  end

  return name
end

local function region_location_columns(region_field, bucket)
  local columns = {}
  local code = bucket["key"]
  if region_field == "request_ip_city" then
    local city = bucket["key"]
  else
    table.insert(columns, {
      v = code,
      f = region_name(code),
    })
  end

  return columns
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

  local results = search:fetch_results()
  local response = {
    stats = {
      total_hits = results["hits"]["total"],
      total_users = results["aggregations"]["unique_user_email"]["value"],
      total_ips = results["aggregations"]["unique_request_ip"]["value"],
      average_response_time = results["aggregations"]["response_time_average"]["value"],
    },
    hits_over_time = hits_over_time(search.interval, results["aggregations"]),
    aggregations = {
      users = aggregation_result(results["aggregations"], "user_email"),
      ips = aggregation_result(results["aggregations"], "request_ip"),
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
    csv.set_response_headers(self, "api_logs_" .. os.date("!%Y-%m-%d", ngx.now()) .. ").csv")
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
          time.elasticsearch_to_csv(row["request_at"]) or null,
          row["request_method"] or null,
          row["request_host"] or null,
          sanitized_full_url(row) or null,
          row["user_email"] or null,
          row["request_ip"] or null,
          row["request_ip_country"] or null,
          row["request_ip_region"] or null,
          row["request_ip_city"] or null,
          row["response_status"] or null,
          row["gatekeeper_denied_code"] or null,
          row["response_time"] or null,
          row["response_content_type"] or null,
          row["request_accept_encoding"] or null,
          row["request_user_agent"] or null,
          row["request_user_agent_family"] or null,
          row["request_user_agent_type"] or null,
          row["request_referer"] or null,
          row["request_origin"] or null,
        }))
      end
      ngx.flush(true)
    end)

    return { layout = false }
  else
    local results = search:fetch_results()
    local response = {
      draw = tonumber(self.params["draw"]),
      recordsTotal = results["hits"]["total"],
      recordsFiltered = results["hits"]["total"],
      data = {}
    }

    for _, hit in ipairs(results["hits"]["hits"]) do
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
  local offset = tonumber(self.params["start"]) or 0
  local limit = tonumber(self.params["length"]) or 0
  if self.params["format"] == "csv" then
    limit = 100000
  end

  -- If we're sorting by hits or last request date, then we can perform the
  -- sorting directly in the elasticsearch query. Otherwise, for user-based
  -- field, we'll need to defer sorting until we have all the results in the
  -- app.
  local order_fields = lapis_datatables.parse_order(self)
  local order_column
  local order_dir
  local order
  if order_fields and order_fields[1] then
    local order_field = order_fields[1]
    order_column = order_field[1]
    order_dir = string.lower(order_field[2])

    if order_column == "hits" then
      order = { _count = order_dir }
    elseif order_column == "last_request_at" then
      order = { [order_column] = order_dir }
    end
  end

  local search = AnalyticsSearch.factory(config["analytics"]["adapter"], {
    start_time = self.params["start_at"],
    end_time = self.params["end_at"],
  })
  search:set_permission_scope(analytics_policy.authorized_query_scope(self.current_admin))
  search:filter_by_time_range()
  search:set_search_query_string(self.params["search"])
  search:set_search_filters(self.params["query"])
  search:aggregate_by_user_stats(order)
  search:set_offset(offset)

  local results = search:fetch_results()
  local buckets = results["aggregations"]["user_stats"]["buckets"]
  local total_count = #buckets

  -- If we were sorting by one of the facet fields, then the sorting has
  -- already been done by elasticsearch. We can improve the performance by
  -- going ahead and truncating the results to the specified page.
  if order then
    buckets = table_sub(buckets, 1, limit)
  end

  local user_ids = {}
  for _, bucket in ipairs(buckets) do
    table.insert(user_ids, bucket["key"])
  end

  local users_by_id = {}
  local users = ApiUser:select("WHERE id IN ?", db.list(user_ids))
  for _, user in ipairs(users) do
    users_by_id[user.id] = user
  end

  -- Build up the results, combining the stats facet information with the user
  -- details.
  local user_data = {}
  for _, bucket in ipairs(buckets) do
    local user_id = bucket["key"]
    local user = users_by_id[user_id] or {}

    table.insert(user_data, {
      id = user_id or json_null,
      email = user.email or json_null,
      first_name = user.first_name or json_null,
      last_name = user.last_name or json_null,
      website = user.website or json_null,
      registration_source = user.registration_source or json_null,
      created_at = time.postgres_to_iso8601(user.created_at) or json_null,
      hits = bucket["doc_count"] or json_null,
      last_request_at = time.timestamp_ms_to_iso8601(bucket["last_request_at"]["value"]) or json_null,
      use_description = user.use_description or json_null,
    })
  end

  -- If sorting was on any of the user fields, now that we have a full result
  -- set now we can manually sort and paginate.
  if not order and order_column and order_dir then
    table.sort(user_data, function(a, b)
      if order_dir == "desc" then
        return tostring(a[order_column]) > tostring(b[order_column])
      else
        return tostring(a[order_column]) < tostring(b[order_column])
      end
    end)
  end

  if self.params["format"] == "csv" then
    csv.set_response_headers(self, "api_users_" .. os.date("!%Y-%m-%d", ngx.now()) .. ".csv")
    ngx.say(csv.row_to_csv({
      "Email",
      "First Name",
      "Last Name",
      "Website",
      "Registration Source",
      "Signed Up (UTC)",
      "Hits",
      "Last Request (UTC)",
      "Use Description",
    }))
    ngx.flush(true)

    for _, row in ipairs(user_data) do
      ngx.say(csv.row_to_csv({
        row["email"] or null,
        row["first_name"] or null,
        row["last_name"] or null,
        row["website"] or null,
        row["registration_source"] or null,
        time.iso8601_to_csv(row["created_at"]) or null,
        row["hits"] or null,
        time.iso8601_to_csv(row["last_request_at"]) or null,
        row["use_description"] or null,
      }))
    end
    ngx.flush(true)

    return { layout = false }
  else
    local response = {
      draw = tonumber(self.params["draw"]) or 0,
      recordsTotal = total_count,
      recordsFiltered = total_count,
      data = user_data,
    }
    setmetatable(response["data"], cjson.empty_array_mt)
    return lapis_json(self, response)
  end
end

function _M.map(self)
  local search = AnalyticsSearch.factory(config["analytics"]["adapter"], {
    start_time = self.params["start_at"],
    end_time = self.params["end_at"],
  })
  search:set_permission_scope(analytics_policy.authorized_query_scope(self.current_admin))
  search:filter_by_time_range()
  search:set_search_query_string(self.params["search"])
  search:set_search_filters(self.params["query"])
  search:aggregate_by_region(self.params["region"])

  local results = search:fetch_results()

  if self.params["format"] == "csv" then
  else
    local region_field = search.body["aggregations"]["regions"]["terms"]["field"]
    local response = {
      region_field = region_field,
      regions = {},
      map_regions = {},
      map_breadcrumbs = {},
    }

    local buckets = results["aggregations"]["regions"]["buckets"]
    for _, bucket in ipairs(buckets) do
      local current_region = self.params["region"]
      local code = bucket["key"]

      table.insert(response["regions"], {
        id = region_id(current_region, code),
        name = region_name(current_region, code),
        hits = bucket["doc_count"],
      })

      local columns = region_location_columns(region_field, bucket)
      table.insert(columns, {
        v = bucket["doc_count"],
        f = number_with_delimiter(bucket["doc_count"]),
      })
      table.insert(response["map_regions"], {
        c = columns
      })
    end

    if results["aggregations"]["missing_regions"]["doc_count"] > 0 then
      table.insert(response["regions"], {
        id = "missing",
        name = t("Unknown"),
        hits = results["aggregations"]["missing_regions"]["doc_count"],
      })
    end

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
