local config = require("api-umbrella.utils.load_config")()

config["elasticsearch"]["template_version"] = 2
if config["elasticsearch"]["api_version"] < 5 then
  config["elasticsearch"]["api_version"] = 5
end

local argparse = require "argparse"
local deepcompare = require("pl.tablex").deepcompare
local elasticsearch_query = require("api-umbrella.utils.elasticsearch").query
local elasticsearch_templates = require "api-umbrella.proxy.elasticsearch_templates_data"
local escape_uri_non_ascii = require "api-umbrella.utils.escape_uri_non_ascii"
local http = require "resty.http"
local icu_date = require "icu-date-ffi"
local inspect = require "inspect"
local is_empty = require "api-umbrella.utils.is_empty"
local json_encode = require "api-umbrella.utils.json_encode"
local log_utils = require "api-umbrella.proxy.log_utils"
local nillify_json_nulls = require "api-umbrella.utils.nillify_json_nulls"
local split = require("pl.utils").split

local format_date = icu_date.formats.pattern("yyyy-MM-dd")
local format_iso8601 = icu_date.formats.iso8601()
local hit_date = icu_date.new()

local bulk_size = 1000
local args = {}

local function table_difference(t1, t2)
  local res = {}
  for k,v in pairs(t1) do
    if not deepcompare(t1[k], t2[k]) then res[k] = v end
  end
  return res
end

local function parse_date(string)
  local date
  if string then
    date = icu_date.new()
    local ok = pcall(date.parse, date, format_date, string)
    if not ok then
      date = nil
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

  local input_scheme, input_host, input_port = unpack(input_uri)
  parsed_args["_input_server"] = {
    scheme = input_scheme,
    host = input_host,
    port = input_port,
  }

  local output_scheme, output_host, output_port = unpack(output_uri)
  parsed_args["_output_server"] = {
    scheme = output_scheme,
    host = output_host,
    port = output_port,
  }

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

local function v1_first_index_time()
  local res, err = elasticsearch_query("/api-umbrella-logs-v1-*/_aliases", {
    server = args["_input_server"],
  })
  if err then
    print("failed to query elasticsearch: " .. err)
    os.exit(1)
  end

  local months = {}
  for index, _ in pairs(res.body_json) do
    local m = ngx.re.match(index, "-(\\d{4})-(\\d{2})")
    if m then
      local date = icu_date.new()
      date:parse(format_iso8601, m[1] .. "-" .. m[2] .. "-01T00:00:00.000Z")
      table.insert(months, date:get_millis())
    end
  end
  table.sort(months)

  local date = icu_date.new()
  date:set_millis(months[1])
  return date
end

local bulk_commands = {}
local last_bulk_commands_timestamp = nil
local function flush_bulk_commands()
  if #bulk_commands == 0 then
    return
  end

  ngx.update_time()
  local benchmark_start = ngx.now()

  print("Indexing records from " .. os.date("!%Y-%m-%dT%TZ", last_bulk_commands_timestamp / 1000))
  io.flush()

  local res, err = elasticsearch_query("/_bulk", {
    server = args["_output_server"],
    method = "POST",
    headers = {
      ["Content-Type"] = "application/x-ndjson",
    },
    body = table.concat(bulk_commands, "\n") .. "\n",
  })
  if err then
    print("unexpected error: " .. err)
    os.exit(1)
  end

  ngx.update_time()
  local benchmark_end = ngx.now()

  local raw_results = res.body_json
  if type(raw_results["items"]) ~= "table" then
    print("unexpected error: " .. (raw_results["items"] or nil))
    os.exit(1)
  end

  local skipped_count = 0
  local created_count = 0
  local error_count = 0
  for _, item in ipairs(raw_results["items"]) do
    if item["create"]["status"] == 409 then
      if args["debug"] then
        io.write(string.char(27) .. "[30m" .. string.char(27) .. "[2m-" .. string.char(27) .. "[0m")
      end
      skipped_count = skipped_count + 1
    elseif item["create"]["status"] == 201 then
      if args["debug"] then
        io.write(string.char(27) .. "[32m" .. string.char(27) .. "[1m✔" .. string.char(27) .. "[0m")
      end
      created_count = created_count + 1
    else
      if args["debug"] then
        io.write(string.char(27) .. "[31m" .. string.char(27) .. "[1m✖" .. string.char(27) .. "[0m")
      end
      print(inspect(item))
      error_count = error_count + 1
    end
  end
  if args["debug"] then
    print("")
  end
  if created_count > 0 then
    print("Created: " .. created_count)
  end
  if skipped_count > 0 then
    print("Skipped (already exists): " .. skipped_count)
  end
  if error_count > 0 then
    print("Errors: " .. error_count)
  end

  local count = #bulk_commands / 2
  print("Indexed " .. count .. " records (" .. (count / (benchmark_end - benchmark_start)) .. " records/sec)")
  io.flush()

  bulk_commands = {}
  last_bulk_commands_timestamp = nil
end

local function process_hit(hit, output_index)
  nillify_json_nulls(hit)

  local source = hit["_source"]
  local data = {
    api_backend_id = source["api_backend_id"],
    api_backend_url_match_id = source["api_backend_url_match_id"],
    denied_reason = source["gatekeeper_denied_code"],
    legacy_api_key = source["api_key"],
    legacy_request_url = source["request_url"],
    legacy_user_email = source["user_email"],
    legacy_user_registration_source = source["user_registration_source"],
    request_accept = source["request_accept"],
    request_accept_encoding = source["request_accept_encoding"],
    request_basic_auth_username = source["request_basic_auth_username"],
    request_connection = source["request_connection"],
    request_content_type = source["request_content_type"],
    request_ip = source["request_ip"],
    request_ip_city = source["request_ip_city"],
    request_ip_country = source["request_ip_country"],
    request_ip_region = source["request_ip_region"],
    request_method = source["request_method"],
    request_origin = source["request_origin"],
    request_referer = source["request_referer"],
    request_size = source["request_size"],
    request_url_hierarchy = source["request_hierarchy"],
    request_url_hierarchy_level0 = source["request_url_hierarchy_level0"],
    request_url_hierarchy_level1 = source["request_url_hierarchy_level1"],
    request_url_hierarchy_level2 = source["request_url_hierarchy_level2"],
    request_url_hierarchy_level3 = source["request_url_hierarchy_level3"],
    request_url_hierarchy_level4 = source["request_url_hierarchy_level4"],
    request_url_hierarchy_level5 = source["request_url_hierarchy_level5"],
    request_url_hierarchy_level6 = source["request_url_hierarchy_level6"],
    request_url_host = source["request_host"],
    request_url_path = source["request_path"],
    request_url_query = source["request_url_query"],
    request_url_scheme = source["request_scheme"],
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
    response_transfer_encoding = source["response_transfer_encoding"],
    timer_response = source["response_time"],
    timestamp_utc = source["request_at"],
    user_id = source["user_id"],
  }

  if type(data["timestamp_utc"]) == "string" then
    hit_date:parse(format_iso8601, data["timestamp_utc"])
    data["timestamp_utc"] = hit_date:get_millis()
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
    imported = source["imported"],
    request_accept = new_hit["request_accept"],
    request_accept_encoding = new_hit["request_accept_encoding"],
    request_at = new_hit["timestamp_utc"],
    request_basic_auth_username = new_hit["request_basic_auth_username"],
    request_connection = new_hit["request_connection"],
    request_content_type = new_hit["request_content_type"],
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
    request_url_hierarchy_level0 = new_hit["request_url_hierarchy_level0"],
    request_url_hierarchy_level1 = new_hit["request_url_hierarchy_level1"],
    request_url_hierarchy_level2 = new_hit["request_url_hierarchy_level2"],
    request_url_hierarchy_level3 = new_hit["request_url_hierarchy_level3"],
    request_url_hierarchy_level4 = new_hit["request_url_hierarchy_level4"],
    request_url_hierarchy_level5 = new_hit["request_url_hierarchy_level5"],
    request_url_hierarchy_level6 = new_hit["request_url_hierarchy_level6"],
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

local function process_hits(results, output_index)
  ngx.update_time()
  local benchmark_start = ngx.now()

  local hits = results["hits"]["hits"]
  local count = #hits
  print(os.date("!%Y-%m-%dT%TZ"))
  print("Fetched " .. count .. " records in " .. results["took"] .. " ms (" .. (count / (results["took"] / 1000)) .. " records/sec)")
  io.flush()

  for _, hit in ipairs(hits) do
    process_hit(hit, output_index)
  end

  flush_bulk_commands()

  ngx.update_time()
  local benchmark_end = ngx.now()

  print("Processed " .. count .. " records (" .. (count / (benchmark_end - benchmark_start)) .. " records/sec)\n")
  io.flush()
end

local function search_day(date_start, date_end)
  local input_index = "api-umbrella-logs-v1-" .. date_start:format(icu_date.formats.pattern("yyyy-MM"))
  local output_index_date = date_start:format(icu_date.formats.pattern("yyyy-MM-dd"))
  local output_index = "api-umbrella-logs-v2-" .. output_index_date

  -- Also query the index for the day before and after to deal with some legacy
  -- data, where the data wasn't in the right date-based index (around month
  -- changes).
  local date_buffer = icu_date.new()
  date_buffer:set_millis(date_start:get_millis())
  date_buffer:add(icu_date.fields.DATE, -1)
  input_index = input_index .. ",api-umbrella-logs-v1-" .. date_buffer:format(icu_date.formats.pattern("yyyy-MM"))

  date_buffer:set_millis(date_start:get_millis())
  date_buffer:add(icu_date.fields.DATE, 1)
  input_index = input_index .. ",api-umbrella-logs-v1-" .. date_buffer:format(icu_date.formats.pattern("yyyy-MM"))

  local res, err = elasticsearch_query("/" .. input_index .. "/log/_search", {
    server = args["_input_server"],
    method = "POST",
    query = {
      scroll = "10m",
    },
    body = {
      sort = "request_at",
      size = bulk_size,
      query = {
        range = {
          request_at = {
            gte = date_start:get_millis(),
            lt = date_end:get_millis(),
          },
        },
      },
    }
  })
  if err then
    print("failed to query elasticsearch: " .. err)
    os.exit(1)
  end

  local raw_results = res.body_json
  process_hits(raw_results, output_index)

  local scroll_id
  while true do
    scroll_id = raw_results["_scroll_id"]
    res, err = elasticsearch_query("/_search/scroll", {
      server = args["_input_server"],
      method = "GET",
      body = {
        scroll = "10m",
        scroll_id = scroll_id,
      },
    })
    if err then
      print("failed to query elasticsearch: " .. err)
      os.exit(1)
    end

    raw_results = res.body_json
    if not raw_results["hits"] or is_empty(raw_results["hits"]["hits"]) then
      break
    end

    process_hits(raw_results, output_index)
  end

  print(os.date("!%Y-%m-%dT%TZ"))
  print("Optimizing '" .. output_index .. "' index...")
  io.flush()
  elasticsearch_query("/" .. output_index .. "/_forcemerge", {
    server = args["_output_server"],
    method = "POST",
    query = {
      max_num_segments = "1",
    },
  })

  print("Creating index aliases for '" .. output_index .. "'...")
  io.flush()
  local aliases = {
    {
      alias = "api-umbrella-logs-" .. output_index_date,
      index = output_index,
    },
    {
      alias = "api-umbrella-logs-write-" .. output_index_date,
      index = output_index,
    },
  }
  for _, alias in ipairs(aliases) do
    -- Only create aliases if they don't already exist.
    local exists_res, exists_err = elasticsearch_query("/_alias/" .. alias["alias"], {
      server = args["_output_server"],
      method = "HEAD",
    })
    if exists_err then
      print("failed to check elasticsearch index alias: " .. exists_err)
      os.exit(1)
    elseif exists_res.status == 404 then
      -- Make sure the index exists.
      elasticsearch_query("/" .. alias["index"], {
        server = args["_output_server"],
        method = "PUT",
      })

      -- Create the alias for the index.
      local _, alias_err = elasticsearch_query("/" .. alias["index"] .. "/_alias/" .. alias["alias"], {
        server = args["_output_server"],
        method = "PUT",
      })
      if alias_err then
        print("failed to create elasticsearch index alias: " .. alias_err)
        os.exit(1)
      end
    end
  end
  print("")
  io.flush()
end

local function search()
  local start_date = args["_start_date"]
  if not start_date then
    start_date = v1_first_index_time()
  end

  local end_date = args["_end_date"]
  if not end_date then
    end_date = icu_date:new()
  end

  local date = start_date
  while date:get_millis() <= end_date:get_millis() do
    local next_day = icu_date.new()
    next_day:set_millis(date:get_millis())
    next_day:add(icu_date.fields.DATE, 1)

    search_day(date, next_day)

    date = next_day
  end
end

local function create_templates()
  for _, template in ipairs(elasticsearch_templates) do
    local _, err = elasticsearch_query("/_template/" .. template["id"], {
      server = args["_output_server"],
      method = "PUT",
      body = template["template"],
    })
    if err then
      print("failed to update elasticsearch template: " .. err)
      os.exit(1)
    end
  end
end

local function run()
  args = parse_args()
  create_templates()
  search()
end

run()
