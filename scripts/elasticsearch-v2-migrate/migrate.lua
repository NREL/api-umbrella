local config = require "api-umbrella.proxy.models.file_config"

-- local Date = require "pl.Date"
local argparse = require "argparse"
local elasticsearch_setup = require "api-umbrella.proxy.jobs.elasticsearch_setup"
local escape_uri_non_ascii = require "api-umbrella.utils.escape_uri_non_ascii"
local http = require "resty.http"
local inspect = require "inspect"
local json_decode = require("cjson").decode
local json_encode = require "api-umbrella.utils.json_encode"
local log_utils = require "api-umbrella.proxy.log_utils"
local luatz = require "luatz"
local nillify_json_nulls = require "api-umbrella.utils.nillify_json_nulls"
local plutils = require "pl.utils"
-- local pretty = require "pl.pretty"
local tablex = require "pl.tablex"

-- local keys = tablex.keys
local split = plutils.split

local bulk_size = 1000
local args = {}

local function table_difference(t1, t2)
  local res = {}
  for k,v in pairs(t1) do
    if not tablex.deepcompare(t1[k], t2[k]) then res[k] = v end
  end
  return res
end

local function parse_date(string)
  local date
  if string then
    local m = ngx.re.match(string, "^(\\d{4})-(\\d{2})-(\\d{2})$")
    if m then
      date = luatz.timetable.new(tonumber(m[1]), tonumber(m[2]), tonumber(m[3]), 0, 0, 0)
    end
  end

  return date
end

local function parse_args()
  local parser = argparse("api-umbrella", "Open source API management")

  parser:option("--input", "Input Elasticsearch database URL."):count(1)
  parser:option("--output", "Output Elasticsearch database URL."):count(1)
  parser:option("--start-date", "Migrate data starting at this date (YYYY-MM-DD format). Defaults to earliest data available from the input database."):count("0-1")
  parser:option("--end-date", "Migrate data ending on this date (YYYY-MM-DD format). Defaults to current date."):count("0-1")
  parser:flag("--debug", "Debug")

  local parsed_args = parser:parse()

  local input_uri, input_err = http:parse_uri(parsed_args["input"], false)
  if not input_uri then
    print("--input could not be parsed. Elasticsearch URL expected.")
    print(input_err)
    os.exit(1)
  end

  local output_uri, _ = http:parse_uri(parsed_args["output"], false)
  if not output_uri then
    print("--output could not be parsed. Elasticsearch URL expected.")
    print(output_uri)
    os.exit(1)
  end

  local _, input_host, input_port = unpack(input_uri)
  parsed_args["input_host"] = input_host
  parsed_args["input_port"] = input_port

  local _, output_host, output_port = unpack(output_uri)
  parsed_args["output_host"] = output_host
  parsed_args["output_port"] = output_port

  if parsed_args["start_date"] then
    parsed_args["_start_date"] = parse_date(parsed_args["start_date"])
    if not parsed_args["_start_date"] then
      print("--start-date could not be parsed. YYYY-MM-DD format expected.")
      os.exit(1)
    end
  end

  if parsed_args["end_date"] then
    parsed_args["_end_date"] = parse_date(parsed_args["end_date"])
    if not parsed_args["_end_date"] then
      print("--start-date could not be parsed. YYYY-MM-DD format expected.")
      os.exit(1)
    end
  end

  return parsed_args
end

local function elasticsearch_query(host, port, options)
  local httpc = http.new()
  httpc:set_timeout(120000)
  httpc:connect({
    scheme = "http",
    host = host,
    port = port,
  })
  local res, err = httpc:request(options)
  if err then
    ngx.log(ngx.ERR, "elasticsearch query failed: " .. err)
    return nil, err
  end

  local body, body_err = res:read_body()
  if not body then
    ngx.log(ngx.ERR, body_err)
    return nil, body_err
  end

  local keepalive_ok, keepalive_err = httpc:set_keepalive()
  if not keepalive_ok then
    ngx.log(ngx.ERR, keepalive_err)
  end

  local response = json_decode(body)
  return response
end

local function v1_first_index_time()
  local res, err = elasticsearch_query(args["input_host"], args["input_port"], {
    method = "GET",
    path = "/api-umbrella-logs-v1-*/_aliases",
  })
  if err then
    ngx.log(ngx.ERR, "unexpected error: " .. err)
    return false
  end

  --print(pretty.write(res))
  local months = {}
  for index, _ in pairs(res) do
    local m = ngx.re.match(index, "-(\\d{4})-(\\d{2})")
    if m then
      local date = luatz.timetable.new(tonumber(m[1]), tonumber(m[2]), 1, 0, 0, 0)
      table.insert(months, date)
    end
  end
  table.sort(months)
  --print(pretty.write(months))
  return months[1]
end

local bulk_commands = {}
local last_bulk_commands_timestamp = nil
local function flush_bulk_commands()
  if #bulk_commands == 0 then
    return
  end

  print("\n" .. os.date("!%Y-%m-%dT%TZ") .. " - Log data from " .. os.date("!%Y-%m-%dT%TZ", last_bulk_commands_timestamp / 1000))

  local httpc = http.new()
  httpc:set_timeout(120000)
  httpc:connect({
    scheme = "http",
    host = config["elasticsearch"]["_first_server"]["host"],
    port = config["elasticsearch"]["_first_server"]["port"],
  })

  local res, err = elasticsearch_query(args["output_host"], args["output_port"], {
    method = "POST",
    path = "/_bulk",
    headers = {
      ["Content-Type"] = "application/json",
    },
    body = table.concat(bulk_commands, "\n") .. "\n",
  })
  if err then
    ngx.log(ngx.ERR, "unexpected error: " .. err)
    return false
  end

  if type(res["items"]) ~= "table" then
    ngx.log(ngx.ERR, "unexpected error: " .. (res["items"] or nil))
    return false
  end

  local skipped_count = 0
  local created_count = 0
  local error_count = 0
  local created_ids = {}
  --print(inspect(res))
  for _, item in ipairs(res["items"]) do
    if item["create"]["status"] == 409 then
      io.write(string.char(27) .. "[30m" .. string.char(27) .. "[2m-" .. string.char(27) .. "[0m")
      skipped_count = skipped_count + 1
    elseif item["create"]["status"] == 201 then
      io.write(string.char(27) .. "[32m" .. string.char(27) .. "[1m✔" .. string.char(27) .. "[0m")
      created_count = created_count + 1
      table.insert(created_ids, item["create"]["_id"])
    else
      io.write(string.char(27) .. "[31m" .. string.char(27) .. "[1m✖" .. string.char(27) .. "[0m")
      error_count = error_count + 1
    end
  end
  print("")
  if created_count > 0 then
    print("Created: " .. created_count)
    -- print("Created IDs: " .. table.concat(created_ids, ", "))
  end
  if skipped_count > 0 then
    print("Skipped (already exists): " .. skipped_count)
  end
  if error_count > 0 then
    print("Errors: " .. error_count)
  end

  bulk_commands = {}
  last_bulk_commands_timestamp = nil
end

local function process_hit(hit, output_index)
  nillify_json_nulls(hit)

  --print(pretty.write(hit))
  local source = hit["_source"]
  local data = {
    api_backend_id = source["api_backend_id"],
    api_backend_url_match_id = source["api_backend_url_match_id"],
    legacy_api_key = source["api_key"],
    denied_reason = source["gatekeeper_denied_code"],
    request_accept = source["request_accept"],
    request_accept_encoding = source["request_accept_encoding"],
    timestamp_utc = source["request_at"],
    request_basic_auth_username = source["request_basic_auth_username"],
    request_connection = source["request_connection"],
    request_content_type = source["request_content_type"],
    request_url_hierarchy = source["request_hierarchy"],
    request_url_hierarchy_level0 = source["request_url_hierarchy_level0"],
    request_url_hierarchy_level1 = source["request_url_hierarchy_level1"],
    request_url_hierarchy_level2 = source["request_url_hierarchy_level2"],
    request_url_hierarchy_level3 = source["request_url_hierarchy_level3"],
    request_url_hierarchy_level4 = source["request_url_hierarchy_level4"],
    request_url_hierarchy_level5 = source["request_url_hierarchy_level5"],
    request_url_hierarchy_level6 = source["request_url_hierarchy_level6"],
    request_url_host = source["request_host"],
    request_ip = source["request_ip"],
    request_ip_city = source["request_ip_city"],
    request_ip_country = source["request_ip_country"],
    request_ip_region = source["request_ip_region"],
    request_method = source["request_method"],
    request_origin = source["request_origin"],
    request_url_path = source["request_path"],
    request_referer = source["request_referer"],
    request_url_scheme = source["request_scheme"],
    request_size = source["request_size"],
    request_url_query = source["request_url_query"],
    request_user_agent = source["request_user_agent"],
    request_user_agent_family = source["request_user_agent_family"],
    request_user_agent_type = source["request_user_agent_type"],
    response_age = source["response_age"],
    response_cache = source["response_cache"],
    response_content_encoding = source["response_content_encoding"],
    response_content_length = source["response_content_length"],
    response_content_type = source["response_content_type"],
    response_server = source["response_server"],
    response_size = source["response_size"],
    response_status = source["response_status"],
    timer_response = source["response_time"],
    response_transfer_encoding = source["response_transfer_encoding"],
    legacy_user_email = source["user_email"],
    user_id = source["user_id"],
    legacy_user_registration_source = source["user_registration_source"],
  }

  if type(data["timestamp_utc"]) == "string" then
    data["timestamp_utc"] = luatz.parse.rfc_3339(data["timestamp_utc"]):timestamp() * 1000
  end

  log_utils.set_url_hierarchy(data)

  if not data["request_url_query"] and source["request_url"] then
    local parts = split(source["request_url"], "?", true, 2)
    if parts[2] then
      data["request_url_query"] = escape_uri_non_ascii(parts[2])
    end
  end

  local new_hit = log_utils.normalized_data(data)
  local new_source = {
    api_backend_id = new_hit["api_backend_id"],
    api_backend_url_match_id = new_hit["api_backend_url_match_id"],
    api_key = new_hit["legacy_api_key"],
    gatekeeper_denied_code = new_hit["denied_reason"],
    request_accept = new_hit["request_accept"],
    request_accept_encoding = new_hit["request_accept_encoding"],
    request_at = new_hit["timestamp_utc"],
    request_basic_auth_username = new_hit["request_basic_auth_username"],
    request_connection = new_hit["request_connection"],
    request_content_type = new_hit["request_content_type"],
    request_hierarchy = new_hit["request_url_hierarchy"],
    request_url_hierarchy_level0 = new_hit["request_url_hierarchy_level0"],
    request_url_hierarchy_level1 = new_hit["request_url_hierarchy_level1"],
    request_url_hierarchy_level2 = new_hit["request_url_hierarchy_level2"],
    request_url_hierarchy_level3 = new_hit["request_url_hierarchy_level3"],
    request_url_hierarchy_level4 = new_hit["request_url_hierarchy_level4"],
    request_url_hierarchy_level5 = new_hit["request_url_hierarchy_level5"],
    request_url_hierarchy_level6 = new_hit["request_url_hierarchy_level6"],
    request_host = new_hit["request_url_host"],
    request_ip = new_hit["request_ip"],
    request_ip_city = new_hit["request_ip_city"],
    request_ip_country = new_hit["request_ip_country"],
    request_ip_region = new_hit["request_ip_region"],
    request_method = new_hit["request_method"],
    request_origin = new_hit["request_origin"],
    request_path = new_hit["request_url_path"],
    request_referer = new_hit["request_referer"],
    request_scheme = new_hit["request_url_scheme"],
    request_size = new_hit["request_size"],
    request_url_query = new_hit["request_url_query"],
    request_user_agent = new_hit["request_user_agent"],
    request_user_agent_family = new_hit["request_user_agent_family"],
    request_user_agent_type = new_hit["request_user_agent_type"],
    response_age = new_hit["response_age"],
    response_cache = new_hit["response_cache"],
    response_content_encoding = new_hit["response_content_encoding"],
    response_content_length = new_hit["response_content_length"],
    response_content_type = new_hit["response_content_type"],
    response_server = new_hit["response_server"],
    response_size = new_hit["response_size"],
    response_status = new_hit["response_status"],
    response_time = new_hit["timer_response"],
    response_transfer_encoding = new_hit["response_transfer_encoding"],
    user_email = new_hit["legacy_user_email"],
    user_id = new_hit["user_id"],
    user_registration_source = new_hit["legacy_user_registration_source"],
    imported = source["imported"],
  }

  if args["debug"] then
    if #bulk_commands % 1000 == 0 then
      print("DIFF - " .. inspect(table_difference(source, new_source)))
      print("DIFF + " .. inspect(table_difference(new_source, source)))
    end
  end

  table.insert(bulk_commands, json_encode({
    create = {
      _index = output_index,
      _type = "log",
      _id = hit["_id"],
    }
  }))
  table.insert(bulk_commands, json_encode(new_source))

  if not last_bulk_commands_timestamp then
    last_bulk_commands_timestamp = data["timestamp_utc"]
  end

  if #bulk_commands >= bulk_size * 2 then
    flush_bulk_commands()
  end
end

local function search_day(date_start, date_end)
  local input_index = string.format("api-umbrella-logs-v1-%04d-%02d", date_start["year"], date_start["month"])
  local output_index = string.format("api-umbrella-logs-v2-%04d-%02d-%02d", date_start["year"], date_start["month"], date_start["day"])
  local scroll_id
  while true do
    local res, err
    if scroll_id then
      res, err = elasticsearch_query(args["input_host"], args["input_port"], {
        method = "GET",
        path = "/_search/scroll",
        query = {
          scroll = "5m",
          scroll_id = scroll_id,
        },
      })
    else
      res, err = elasticsearch_query(args["input_host"], args["input_port"], {
        method = "GET",
        path = "/" .. input_index .. "/_search",
        query = {
          scroll = "5m",
          scroll_id = scroll_id,
        },
        headers = {
          ["Content-Type"] = "application/json",
        },
        body = json_encode({
          sort = "request_at",
          size = bulk_size,
          query = {
            range = {
              request_at = {
                gte = date_start:timestamp() * 1000,
                lt = date_end:timestamp() * 1000,
              },
            },
          },
        })
      })
    end
    if err then
      ngx.log(ngx.ERR, "elasticsearch query failed: " .. err)
      return false
    end

    scroll_id = res["_scroll_id"]
    --print "."
    -- print(inspect(response))
    if not res["hits"] or not res["hits"]["hits"] or #res["hits"]["hits"] == 0 then
      break
    end

    for _, hit in ipairs(res["hits"]["hits"]) do
      process_hit(hit, output_index)
    end
  end

  flush_bulk_commands()

  elasticsearch_query(args["output_host"], args["output_port"], {
    method = "POST",
    path = "/" .. output_index .. "/_forcemerge",
    query = {
      max_num_segments = "1",
    },
  })
end

local function search()
  local start_date = args["_start_date"]
  if not start_date then
    start_date = v1_first_index_time()
  end

  local end_date = args["_end_date"]
  if not end_date then
    end_date = luatz.now()
  end

  local date = start_date
  while date:timestamp() <= end_date:timestamp() do
    local next_day = date:clone()
    next_day["day"] = next_day["day"] + 1
    next_day:normalise()

    search_day(date, next_day)

    date = next_day
  end
end

local function run()
  args = parse_args()

  elasticsearch_setup.wait_for_elasticsearch()
  elasticsearch_setup.create_templates()

  search()
end

run()
