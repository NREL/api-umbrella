local cjson = require "cjson"
local http = require "resty.http"
local read_config = require "api-umbrella.cli.read_config"
local unistd = require "posix.unistd"

local function health(options, config)
  local status = "red"
  local exit_code = 1

  local url = "http://127.0.0.1:" .. config["http_port"] .. "/api-umbrella/v1/health"
  if options["wait_for_status"] then
    url = url .. "?wait_for_status=" .. options["wait_for_status"] .. "&wait_timeout=" .. options["wait_timeout"]
  end

  local httpc = http.new()
  local res, http_err = httpc:request_uri(url)
  if not res then
    return status, exit_code, http_err
  elseif res.headers["Content-Type"] ~= "application/json" then
    local err = "nginx error"
    return status, exit_code, err
  else
    local data = cjson.decode(res.body)
    if data["status"] then
      status = data["status"]

      if res.status == 200 and status ~= "red" then
        exit_code = 0
      end
    else
      local err = "nginx error"
      return status, exit_code, err
    end
  end

  return status, exit_code
end

return function(options)
  local config = read_config()

  -- Perform a health check using the API health endpoint.
  --
  -- By default, perform the health check and return the status immediately.
  --
  -- If the --wait-for-status option is given, then the CLI app will wait until
  -- that status (or better) is met (or until timeout).
  local status, exit_code, health_err, _
  if not options["wait_for_status"] then
    status, exit_code, _ = health(options, config)
  else
    -- Validate the wait_for_status param.
    local wait_for_status = options["wait_for_status"]
    if wait_for_status ~= "green" and wait_for_status ~= "yellow" and wait_for_status ~= "red" then
      print("Error: invalid --wait-for-status argument (" .. (tostring(wait_for_status) or "") .. ")")
      os.exit(1)
    end

    -- Validate the wait_timeout param (defaults to 50 seconds).
    local wait_timeout = tonumber(options["wait_timeout"] or 50)
    if not wait_timeout then
      print("Error: invalid --wait-timeout argument (" .. (tostring(wait_timeout) or "") .. ")")
      os.exit(1)
    end

    -- Most of the wait-for-status functionality is implemented within the API
    -- endpoint (will will wait until the expected status is achieved).
    -- However, we will also loop in the CLI app until this status is achieved
    -- to handle connection errors if nginx hasn't yet bound to the expected
    -- port.
    local timeout_at = os.time() + wait_timeout
    while true do
      status, exit_code, health_err = health(options, config)

      -- If a low-level connection error wasn't returned, then we assume the
      -- API endpoint was hit and it already waited the proper amount of time,
      -- so we should immediately return whatever status the API returned.
      if not health_err then
        break
      end

      -- Bail if we've exceeded the timeout waiting.
      if os.time() > timeout_at then
        break
      end

      unistd.sleep(1)
    end
  end

  print(status or "red")
  os.exit(exit_code or 1)
end
