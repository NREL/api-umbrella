local inspect = require "inspect"
local distributed_rate_limit_queue = require "api-umbrella.proxy.distributed_rate_limit_queue"

local function bucket_keys(user, limit, current_time, max_keys)
  local bucket_time = math.floor(current_time / limit["accuracy"]) * limit["accuracy"]
  local num_buckets = math.ceil(limit["duration"] / limit["accuracy"])

  local key_base = limit["limit_by"] .. ":" .. limit["duration"] .. ":"
  local limit_by = limit["limit_by"]
  if not user or user.throttle_by_ip then
    limit_by = "ip"
  end

  if limit_by == "apiKey" then
    key_base = key_base .. user["api_key"]
  elseif limit_by == "ip" then
    key_base = key_base .. ngx.ctx.remote_addr
  else
    ngx.log(ngx.ERR, "stats unknown limit by")
  end

  local bucket_keys = {}
  for i = 0, num_buckets - 1 do
    local key = key_base .. ":" .. (bucket_time - limit["accuracy"] * i)
    table.insert(bucket_keys, key)

    if max_keys and i + 1 >= max_keys then
      break
    end
  end

  return bucket_keys
end

local function increment_limit(current_time_key, duration, distributed)
  local bucket_count, err = ngx.shared.stats:incr(current_time_key, 1)
  if err == "not found" then
    bucket_count = 1
    local success, err = ngx.shared.stats:set(current_time_key, bucket_count, duration / 1000)
    if not success then
      ngx.log(ngx.ERR, "stats set err: ", err)
      return
    end
  elseif err then
    ngx.log(ngx.ERR, "stats incr err: ", err)
    return
  end

  if distributed then
    distributed_rate_limit_queue.push(current_time_key)
  end
end

local function get_remaining_for_limit(settings, user, limit, current_time)
  local anonymous_rate_limit_behavior = settings["anonymous_rate_limit_behavior"]
  local authenticated_rate_limit_behavior = settings["authenticated_rate_limit_behavior"]
  if limit["limit_by"] == "apiKey" and not user and anonymous_rate_limit_behavior == "ip_only" then
    return nil
  elseif limit["limit_by"] == "ip" and user and authenticated_rate_limit_behavior == "api_key_only" then
    return nil
  end

  local keys = bucket_keys(user, limit, current_time)
  limit["_current_time_key"] = keys[1]

  local remaining = limit["limit"] - 1
  for index, key in ipairs(keys) do
    local bucket_count = ngx.shared.stats:get(key)
    if bucket_count then
      remaining = remaining - bucket_count
    end

    if remaining < 0 then
      break
    end
  end

  return remaining
end

local function is_over_any_limits(settings, user, current_time)
  local over_limit = false

  local limits = settings["rate_limits"]
  for _, limit in ipairs(limits) do
    if not over_limit or limit["response_headers"] then
      local remaining = get_remaining_for_limit(settings, user, limit, current_time)
      if remaining then
        if remaining < 0 then
          over_limit = true
          remaining = 0
        end

        if limit["response_headers"] then
          ngx.header["X-RateLimit-Limit"] = limit["limit"]
          ngx.header["X-RateLimit-Remaining"] = remaining
        end
      end
    end
  end

  return over_limit
end

local function increment_all_limits(limits, user, current_time)
  for _, limit in ipairs(limits) do
    -- Make sure the current time key gets set in case this limit wasn't hit
    -- earlier in get_remaining_for_limit.
    if not limit["_current_time_key"] then
      local keys = bucket_keys(user, limit, current_time, 1)
      limit["_current_time_key"] = keys[1]
    end

    increment_limit(limit["_current_time_key"], limit["duration"], limit["distributed"])
  end
end

return function(settings, user)
  if settings["rate_limit_mode"] == "unlimited" then
    return
  end

  local current_time = math.floor(ngx.now() * 1000)
  if config["app_env"] == "test" then
    local fake_time = ngx.var.http_x_fake_time
    if fake_time then
      current_time = tonumber(fake_time)
    end
  end

  local over_limit = is_over_any_limits(settings, user, current_time)
  if over_limit then
    return "over_rate_limit"
  else
    increment_all_limits(settings["rate_limits"], user, current_time)
  end
end
