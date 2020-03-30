local setenv = require("posix.stdlib").setenv
setenv("API_UMBRELLA_RUNTIME_CONFIG", os.getenv("API_UMBRELLA_ROOT") .. "/var/run/runtime_config.yml")

local argparse = require "argparse"
local icu_date = require "icu-date-ffi"
local json_decode = require("cjson").decode
local log_utils = require "api-umbrella.proxy.log_utils"
local shell_blocking_capture_combined = require("shell-games").capture_combined
local split = require("ngx.re").split

local format_iso8601 = icu_date.formats.iso8601()

local function parse_time(string)
  local date
  if string then
    date = icu_date.new()
    local ok = pcall(date.parse, date, format_iso8601, string)
    if not ok then
      date = nil
    end
  end

  return date
end

local function parse_args()
  local parser = argparse("api-umbrella", "Open source API management")

  parser:option("--profile", "AWS Profile"):count(1)
  parser:option("--group", "CloudWatch group"):count(1)
  parser:option("--start", "Migrate data starting at this time (YYYY-MM-DDThh:mm:ss.sssZ format)."):count(1)
  parser:option("--stop", "Migrate data ending on this time (YYYY-MM-DDThh:mm:ss.sssZ format)."):count(1)

  local parsed_args = parser:parse()

  parsed_args["_start"] = parse_time(parsed_args["start"])
  if not parsed_args["_start"] then
    print("--start-date could not be parsed. YYYY-MM-DD format expected.")
    os.exit(1)
  end

  parsed_args["_stop"] = parse_time(parsed_args["stop"])
  if not parsed_args["_stop"] then
    print("--start-date could not be parsed. YYYY-MM-DD format expected.")
    os.exit(1)
  end

  return parsed_args
end

local function process_minute(args, start, stop)
  start = start:format(format_iso8601)
  stop = stop:format(format_iso8601)
  print("Fetching logs from " .. start .. " to " .. stop .. "...")
  local saw_args = {
    "saw",
    "get",
    args["group"],
    "--start", start,
    "--stop", stop,
    "--filter", [[{ $.log = "*[rsyslog] {*" }]],
    "--rawString",
  }
  if args["profile"] then
    table.insert(saw_args, "--profile")
    table.insert(saw_args, args["profile"])
  end

  local result, saw_err = shell_blocking_capture_combined(saw_args)
  if saw_err then
    ngx.log(ngx.ERR, saw_err)
    os.exit(1)
  end

  local lines = split(result["output"], "[\r\n]+")
  print("Processing logs from " .. start .. " to " .. stop .. " (" .. #lines .. " records)...")
  for _, line in ipairs(lines) do
    io.write(".")

    local line_data = json_decode(line)
    local match, match_err = ngx.re.match(line_data["log"], [[\[rsyslog\] (\{.+\})$]])
    if match_err then
      ngx.log(ngx.ERR, "regex error: ", match_err)
      os.exit(1)
    end
    local log_data = json_decode(match[1])

    local syslog_message = log_utils.build_syslog_message(log_data)
    local _, log_err = log_utils.send_syslog_message(syslog_message)
    if log_err then
      ngx.log(ngx.ERR, "failed to log message: ", log_err)
      os.exit(1)
    end
  end
  io.write("\n")
end

local function process(args)
  local date = args["_start"]
  while date:get_millis() <= args["_stop"]:get_millis() do
    local next_minute = icu_date.new()
    next_minute:set_millis(date:get_millis())
    next_minute:add(icu_date.fields.MINUTE, 1)

    process_minute(args, date, next_minute)

    date = next_minute
  end
end

local function run()
  local args = parse_args()
  process(args)
end

run()
