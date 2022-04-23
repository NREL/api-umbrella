local config = require("api-umbrella.utils.load_config")()
local distributed_rate_limit_queue = require "api-umbrella.proxy.distributed_rate_limit_queue"

local function bucket_keys(settings, user, limit, current_time)
  local bucket_time = math.floor(current_time / limit["accuracy"]) * limit["accuracy"]

  local key_base = limit["limit_by"] .. ":" .. limit["duration"] .. ":"
  local limit_by = limit["limit_by"]
  if not user or user["throttle_by_ip"] then
    limit_by = "ip"
  end

  if limit_by == "api_key" then
    key_base = key_base .. user["id"]
  elseif limit_by == "ip" then
    key_base = key_base .. ngx.ctx.remote_addr
  else
    ngx.log(ngx.ERR, "stats unknown limit by")
  end

  if settings["rate_limit_bucket_name"] then
    key_base = key_base .. ":" .. settings["rate_limit_bucket_name"]
  else
    local matched_api = ngx.ctx.matched_api
    if matched_api and matched_api["frontend_host"] then
      key_base = key_base .. ":" .. matched_api["frontend_host"]
    end
  end

  local keys = {}
  for _, time_diff in ipairs(limit["_bucket_time_diffs"]) do
    local key = key_base .. ":" .. (bucket_time - time_diff)
    table.insert(keys, key)
  end

  return keys
end

local function increment_limit(current_time_key, duration, distributed)
  local ok, count, err

  -- Try to increment an existing key.
  count, err = ngx.shared.stats:incr(current_time_key, 1)
  if err then
    -- If the increment failed because the key doesn't exist, add it as a new
    -- key.
    if err == "not found" then
      count = 1
      ok, err = ngx.shared.stats:add(current_time_key, count, duration / 1000)
      if not ok then
        -- If the add failed because they key already exists, make another
        -- attempt at incrementing it again.
        --
        -- This is to prevent a theoretical race condition if the key gets
        -- added by another process in-between the initial increment and add
        -- attempts, which would cause the add to fail (although I'm not sure
        -- this is really possible, since we're not performing any other async
        -- tasks between the incr and add).
        if err == "exists" then
          count, err = ngx.shared.stats:incr(current_time_key, 1)
          if err then
            ngx.log(ngx.ERR, "stats incr retry err: ", err)
          end
        else
          ngx.log(ngx.ERR, "stats add err: ", err)
        end
      end
    else
      ngx.log(ngx.ERR, "stats incr err: ", err)
    end
  end

  if distributed then
    distributed_rate_limit_queue.push(current_time_key)
  end

  return count or 1
end

local function get_remaining_for_limit(settings, user, limit, keys)
  -- Keep track of the bucket of the current time for later use.
  local current_time_key_index = #keys
  limit["_current_time_key"] = keys[current_time_key_index]

  -- These two settings act to disable IP vs API key limits depending on
  -- whether or not anonymous users are allowed. So return nil if either
  -- setting is forcing this limit to be disabled in the current request's
  -- context.
  local anonymous_rate_limit_behavior = settings["anonymous_rate_limit_behavior"]
  local authenticated_rate_limit_behavior = settings["authenticated_rate_limit_behavior"]
  if limit["limit_by"] == "api_key" and not user and anonymous_rate_limit_behavior == "ip_only" then
    return nil
  elseif limit["limit_by"] == "ip" and user and authenticated_rate_limit_behavior == "api_key_only" then
    return nil
  end

  -- Fetch all of the hit counts for each time bucket on this limit. Keep
  -- subtracting them from the limit to determine if the user has exceeded
  -- their limit.
  local remaining = limit["limit_to"]
  for index, key in ipairs(keys) do
    local bucket_count = ngx.shared.stats:get(key) or 0

    -- Keep track of the bucket count of the current time for later use.
    if index == current_time_key_index then
      bucket_count = bucket_count + 1
      limit["_current_time_count"] = bucket_count
    end

    remaining = remaining - bucket_count

    -- If the user has exceeded their limit, halt further processing on this
    -- bucket, since we don't need to perform any further calculations.
    if remaining < 0 then
      break
    end
  end

  limit["_remaining"] = remaining

  return remaining
end

local function process_remaining(limit, remaining, over_limit)
  if remaining then
    if remaining < 0 then
      over_limit = true
      remaining = 0
    end

    if limit["response_headers"] then
      ngx.ctx.response_header_limit = limit["limit_to"]
      ngx.ctx.response_header_remaining = remaining
    end
  end

  return over_limit
end

local function is_over_any_limits(settings, user, current_time)
  local over_limit = false

  -- Loop over each limit present and see if any one of them has been exceeded.
  local limits = settings["rate_limits"]
  for _, limit in ipairs(limits) do
    -- Skip processing if the rate limit has been exceeded, except for limits
    -- where we want to return the current counts in the response headers (so
    -- we can fetch the counts to returning the remaining count).
    if not over_limit or limit["response_headers"] then
      local keys = bucket_keys(settings, user, limit, current_time)
      local remaining = get_remaining_for_limit(settings, user, limit, keys)
      over_limit = process_remaining(limit, remaining, over_limit)
    end
  end

  return over_limit
end

local function increment_all_limits(settings)
  local over_limit = false

  for _, limit in ipairs(settings["rate_limits"]) do
    local increment_count = increment_limit(limit["_current_time_key"], limit["duration"], limit["distributed"])

    -- Since we fetch all of our rate limit counts first, and then increment
    -- the counts separately (to ensure we don't increment requests that have
    -- already exceeded their limits), we have a possible race condition.
    -- Because these two separate operations aren't atomic, it's possible other
    -- concurrent requests have also incremented this same bucket in between
    -- the initial fetch and now. Since the result from the increment operation
    -- is atomic, it should always be correct. So check for differences between
    -- the original metrics and the increment count, and adjust the overall
    -- count appropriately. Double-check to ensure the new, more accurate count
    -- doesn't exceed any rate limits.
    --
    -- Note: There is still theoretically another, similar race condition
    -- present, but it should be far more rare and the cost involved in solving
    -- it doesn't seem worth it. If this request is taking place right at the
    -- beginning of the rate limit bucket's time window (for example, if the
    -- accuracy is 1 minute, and the request happens at the very beginning of a
    -- new minute), then it's possible other requests may have also impacted
    -- the previous bucket's counts since we last fetched the metrics on this
    -- request (in the example, the counts for the previous minute). In this
    -- case, our metrics for this request might not be 100% accurate, since we
    -- don't have the updated counts for the previous bucket. To solve this,
    -- we'd have to also re-fetch the counts for the previous bucket, but it
    -- doesn't seem worth the extra cost since this condition should be pretty
    -- rare and the actual impact seems minimal (1-2 extra requests may be
    -- allowed before the updated metrics are fetched on subsequent requests).
    if increment_count and limit["_current_time_count"] and increment_count ~= limit["_current_time_count"] then
      local remaining = limit["_remaining"] - (increment_count - limit["_current_time_count"])
      over_limit = process_remaining(limit, remaining, over_limit)
    end
  end

  return over_limit
end

return function(settings, user)
  if settings["rate_limit_mode"] == "unlimited" then
    return
  end

  local current_time = math.floor(ngx.now() * 1000)
  local test_env_skip_increment_limits = false
  if config["app_env"] == "test" then
    local fake_time = ngx.var.http_x_fake_time
    if fake_time then
      current_time = tonumber(fake_time)
    end

    if ngx.var.http_x_api_umbrella_test_skip_increment_limits == "true" then
      test_env_skip_increment_limits = true
    end
  end

  -- First check to see if the current request is over any rate limits.
  local over_limit = is_over_any_limits(settings, user, current_time)

  -- If the request isn't over any limits, then increment all the rate limit
  -- values (we only do this when not over limits so that over rate limit
  -- requests don't count against the user).
  if not over_limit and not test_env_skip_increment_limits then
    over_limit = increment_all_limits(settings)
  elseif test_env_skip_increment_limits then
    -- If we're in the test environment and incrementing rate limits is
    -- disabled, then add 1 back to the remaining count (since this hit hasn't
    -- actually subtracted 1).
    ngx.ctx.response_header_remaining = ngx.ctx.response_header_remaining + 1
  end

  if ngx.ctx.response_header_limit then
    ngx.header["X-RateLimit-Limit"] = ngx.ctx.response_header_limit
  end
  if ngx.ctx.response_header_remaining then
    ngx.header["X-RateLimit-Remaining"] = ngx.ctx.response_header_remaining
  end

  if over_limit then
    return "over_rate_limit"
  end
end
