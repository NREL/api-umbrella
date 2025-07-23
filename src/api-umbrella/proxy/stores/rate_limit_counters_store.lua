local config = require("api-umbrella.utils.load_config")()
local int64 = require "api-umbrella.utils.int64"
local is_empty = require "api-umbrella.utils.is_empty"
local lrucache = require "resty.lrucache.pureffi"
local pg_utils = require "api-umbrella.utils.pg_utils"
local shared_dict_retry = require "api-umbrella.utils.shared_dict_retry"
local split = require("pl.utils").split
local table_clear = require "table.clear"
local table_copy = require("pl.tablex").copy
local table_new = require "table.new"

local ceil = math.ceil
local counters_dict = ngx.shared.rate_limit_counters
local cursor = pg_utils.cursor
local exceeded_dict = ngx.shared.rate_limit_exceeded
local floor = math.floor
local int64_min_value_string = int64.MIN_VALUE_STRING
local int64_to_string = int64.to_string
local jobs_dict = ngx.shared.jobs
local ngx_var = ngx.var
local now = ngx.now
local query = pg_utils.query
local shared_dict_retry_incr = shared_dict_retry.incr
local shared_dict_retry_set = shared_dict_retry.set

-- Rate limit implementation loosely based on
-- https://blog.cloudflare.com/counting-things-a-lot-of-different-things/
--
-- - Each rate limit applied uses two counters: One for the current time period
--   and one for the previous time period. The estimated rate is calculated
--   based on these.
-- - When the rate limit has been exceeded, this is cached locally so no
--   further calculations are necessary for these requests.

local _M = {}

local exceeded_local_cache = lrucache.new(1000)
local distributed_counters_local_queue = table_new(0, 1000)

local function get_bucket_name(api, settings)
  local bucket_name
  if settings["rate_limit_bucket_name"] then
    bucket_name = settings["rate_limit_bucket_name"]
  else
    if api then
      bucket_name = api["frontend_host"]
    end

    if not bucket_name then
      bucket_name = "*"
    end
  end

  return bucket_name
end

local function get_rate_limit_key(self, rate_limit_index, rate_limit)
  local cached_key = self.rate_limit_keys[rate_limit_index]
  if cached_key then
    return cached_key
  end

  local limit_by = rate_limit["limit_by"]

  local key_limit_by
  if limit_by == "api_key" then
    key_limit_by = "k"
  elseif limit_by == "ip" then
    key_limit_by = "i"
  else
    ngx.log(ngx.ERR, "rate limit unknown limit by")
  end

  local user = self.user
  if not user or user["throttle_by_ip"] then
    limit_by = "ip"
  end

  local key_value
  if limit_by == "api_key" then
    key_value = user["api_key_prefix"]
  elseif limit_by == "ip" then
    key_value = self.remote_addr
  else
    ngx.log(ngx.ERR, "rate limit unknown limit by")
  end

  local key = key_limit_by .. "|" .. rate_limit["_duration_sec"] .. "|" .. self.bucket_name .. "|" .. key_value
  self.rate_limit_keys[rate_limit_index] = key
  return key
end

local function increment_distributed_counter(key, increment_by)
  local value = distributed_counters_local_queue[key]
  if not value then
    distributed_counters_local_queue[key] = increment_by
  else
    distributed_counters_local_queue[key] = value + increment_by
  end
end

local function has_already_exceeded_any_limits(self)
  local current_time = self.current_time
  local exceed_expires_at
  local exceeded = false
  local header_remaining
  local header_retry_after

  -- Loop over each limit present and see if any one of them has been exceeded.
  for rate_limit_index, rate_limit in ipairs(self.rate_limits) do
    local rate_limit_key = get_rate_limit_key(self, rate_limit_index, rate_limit)

    exceed_expires_at = exceeded_local_cache:get(rate_limit_key)
    if exceed_expires_at then
      break
    else
      local exceed_expires_at_err
      exceed_expires_at, exceed_expires_at_err = exceeded_dict:get(rate_limit_key)
      if not exceed_expires_at and exceed_expires_at_err then
        ngx.log(ngx.ERR, "Error fetching rate limit exceeded: ", exceed_expires_at_err)
      elseif exceed_expires_at then
        shared_dict_retry_set(exceeded_local_cache, rate_limit_key, exceed_expires_at, exceed_expires_at - current_time)
        break
      end
    end
  end

  if exceed_expires_at and exceed_expires_at >= current_time then
    exceeded = true
    header_remaining = 0
    header_retry_after = ceil(exceed_expires_at - current_time)
  end

  return exceeded, header_remaining, header_retry_after
end

local function check_limit(rate_limit_key, rate_limit, limit_to, duration, increment_by, current_time, current_period_key, current_period_start_time, current_period_count)
  local exceeded = false
  local remaining
  local retry_after

  local estimated_count
  local time_in_current_period = current_time - current_period_start_time
  local time_portion_from_previous_period = duration - time_in_current_period

  -- If the number of requests in the current time period have exceeded the
  -- limit, then there's no need to fetch the previous time period's counts.
  if current_period_count > limit_to then
    exceeded = true
    retry_after = floor(time_portion_from_previous_period) + 1
    estimated_count = current_period_count
  else
    -- Fetch the requests made in the previous time period (eg, if this is an
    -- rate limit with a 1 hour duration, the requests in the previous hour).
    local previous_period_start_time = current_period_start_time - duration
    local previous_period_key = rate_limit_key .. "|" .. previous_period_start_time
    local previous_period_count, previous_period_count_err = counters_dict:get(previous_period_key)
    if not previous_period_count then
      if previous_period_count_err then
        ngx.log(ngx.ERR, "Error fetching rate limit counter: ", previous_period_count_err)
      end

      previous_period_count = 0
    end

    -- Calculate the estimated number of requests made during the duration by
    -- using the count from the current period plus a weighted average of the
    -- requests from the previous period.
    --
    -- This assumes a constant rate of requests, which may not be entirely
    -- accurate, but as explained here, this is usually pretty accurate while
    -- being easy to compute:
    -- https://blog.cloudflare.com/counting-things-a-lot-of-different-things/#slidingwindowstotherescue
    local time_weighted_previous_period_count = floor(previous_period_count * (time_portion_from_previous_period / duration))
    estimated_count = current_period_count + time_weighted_previous_period_count

    if estimated_count > limit_to then
      exceeded = true

      local target_previous_period_count_for_retry_after = limit_to - current_period_count
      retry_after = floor(duration - ((target_previous_period_count_for_retry_after / previous_period_count) * duration)) + 1
    end
  end

  if exceeded then
    remaining = 0

    -- In the event the rate limit has been exceeded, cache this for as long as
    -- we know the rate limit will still be considered exceeded (based on the
    -- estimated rate) so we can bypass any calculations on further over rate
    -- limit requests.
    local exceed_expires_at = current_time + retry_after
    local set_ok, set_err, set_forcible = shared_dict_retry_set(exceeded_dict, rate_limit_key, exceed_expires_at, retry_after)
    if not set_ok then
      ngx.log(ngx.ERR, "failed to set exceeded key in 'rate_limit_exceeded' shared dict: ", set_err)
    elseif set_forcible then
      ngx.log(ngx.WARN, "forcibly set exceeded key in 'rate_limit_exceeded' shared dict (shared dict may be too small)")
    end

    -- If the rate limit has been exceeded, then decrement the counters for the
    -- current time period since this request will actually be rejected.
    --
    -- We perform an increment earlier to fetch the current period's count.
    -- This increment and then decrement approach is preferable to a separate
    -- get and then a conditional increment, since it keeps the increment
    -- operation atomic, so there's fewer race conditions. And since we cache
    -- rate limit exceeded situations to prevent further counts for the
    -- duration of being over rate limit (see above), that should mean there's
    -- not a ton of these increment then decrement operations performed.
    local _, decr_err = shared_dict_retry_incr(counters_dict, current_period_key, -1)
    if decr_err then
      ngx.log(ngx.ERR, "failed to decrement counters shared dict: ", decr_err)
    end
  else
    remaining = limit_to - estimated_count

    if rate_limit["distributed"] and increment_by > 0 then
      increment_distributed_counter(current_period_key, increment_by)
    end
  end

  return exceeded, remaining, retry_after
end

local function increment_limit(self, increment_by, rate_limit_index, rate_limit)
  local rate_limit_key = get_rate_limit_key(self, rate_limit_index, rate_limit)

  local current_time = self.current_time
  local duration = rate_limit["_duration_sec"]
  local current_period_start_time = floor(floor(current_time / duration) * duration)
  local current_period_key = rate_limit_key .. "|" .. current_period_start_time
  local current_period_ttl = ceil(duration * 2 + 1)
  local current_period_count, incr_err, incr_forcible = shared_dict_retry_incr(counters_dict, current_period_key, increment_by, 0, current_period_ttl)
  if incr_err then
    ngx.log(ngx.ERR, "failed to increment counters shared dict: ", incr_err)
  elseif incr_forcible then
    ngx.log(ngx.WARN, "forcibly set counter in 'rate_limit_counters' shared dict (shared dict may be too small)")
  end

  return check_limit(rate_limit_key, rate_limit, rate_limit["limit_to"], duration, increment_by, current_time, current_period_key, current_period_start_time, current_period_count)
end

local function increment_all_limits(self, increment_by)
  local exceeded = false
  local header_remaining
  local header_retry_after

  for rate_limit_index, rate_limit in ipairs(self.rate_limits) do
    local limit_exceeded, limit_remaining, limit_retry_after = increment_limit(self, increment_by, rate_limit_index, rate_limit)

    if rate_limit["response_headers"] or limit_exceeded then
      header_remaining = limit_remaining
      header_retry_after = limit_retry_after
    end

    if limit_exceeded then
      exceeded = true
      break
    end
  end

  return exceeded, header_remaining, header_retry_after
end

function _M.check(api, settings, user, remote_addr)
  if settings["rate_limit_mode"] == "unlimited" then
    return false
  end

  local rate_limits = {}
  local anonymous_rate_limit_behavior = settings["anonymous_rate_limit_behavior"]
  local authenticated_rate_limit_behavior = settings["authenticated_rate_limit_behavior"]
  for _, rate_limit in ipairs(settings["rate_limits"]) do
    -- These two settings act to disable IP vs API key limits depending on
    -- whether or not anonymous users are allowed. So skip processing if either
    -- setting is forcing this limit to be disabled in the current request's
    -- context.
    local limit_by = rate_limit["limit_by"]
    if not ((limit_by == "api_key" and not user and anonymous_rate_limit_behavior == "ip_only") or (limit_by == "ip" and user and authenticated_rate_limit_behavior == "api_key_only")) then
      table.insert(rate_limits, rate_limit)
    end
  end

  local self = {
    api = api,
    settings = settings,
    user = user,
    current_time = now(),
    bucket_name = get_bucket_name(api, settings),
    rate_limits = rate_limits,
    rate_limit_keys = table_new(0, #rate_limits),
    remote_addr = remote_addr,
  }

  local increment_by = 1
  if config["app_env"] == "test" then
    local fake_time = ngx_var.http_x_fake_time
    if fake_time then
      self.current_time = tonumber(fake_time)
      exceeded_dict:flush_all()
      exceeded_local_cache:flush_all()
    end

    if ngx_var.http_x_api_umbrella_test_skip_increment_limits == "true" then
      increment_by = 0
    end
  end

  local exceeded, header_remaining, header_retry_after = has_already_exceeded_any_limits(self)
  if not exceeded then
    exceeded, header_remaining, header_retry_after = increment_all_limits(self, increment_by)
  end

  local header_limit
  if header_remaining then
    header_limit = settings["_rate_limits_response_header_limit"]
  end

  return exceeded, header_limit, header_remaining, header_retry_after
end

function _M.distributed_push()
  if is_empty(distributed_counters_local_queue) then
    return
  end

  local current_save_time = now()
  local data = table_copy(distributed_counters_local_queue)
  table_clear(distributed_counters_local_queue)

  local success = true
  for key, count in pairs(data) do
    local key_parts = split(key, "|", true)
    local duration = tonumber(key_parts[2])
    local period_start_time = tonumber(key_parts[5])
    local expires_at = ceil(period_start_time + duration * 2 + 1)

    local result, err = query("INSERT INTO distributed_rate_limit_counters(id, value, expires_at) VALUES(:id, :value, to_timestamp(:expires_at)) ON CONFLICT (id) DO UPDATE SET value = distributed_rate_limit_counters.value + EXCLUDED.value", {
      id = key,
      value = count,
      expires_at = expires_at,
    }, { quiet = true })
    if not result then
      ngx.log(ngx.ERR, "failed to update rate limits in database: ", err)
      success = false
    end
  end

  if success then
    local set_ok, set_err, set_forcible = shared_dict_retry_set(jobs_dict, "rate_limit_counters_store_distributed_last_pushed_at", current_save_time * 1000)
    if not set_ok then
      ngx.log(ngx.ERR, "failed to set 'rate_limit_counters_store_distributed_last_pushed_at' in 'jobs' shared dict: ", set_err)
    elseif set_forcible then
      ngx.log(ngx.WARN, "forcibly set 'rate_limit_counters_store_distributed_last_pushed_at' in 'jobs' shared dict (shared dict may be too small)")
    end
  end
end

function _M.distributed_pull()
  local current_fetch_time = now()
  local last_fetched_version, last_fetched_version_err = jobs_dict:get("rate_limit_counters_store_distributed_last_fetched_version")
  if not last_fetched_version then
    if last_fetched_version_err then
      ngx.log(ngx.ERR, "Error fetching rate limit counter: ", last_fetched_version_err)
    end

    last_fetched_version = int64_min_value_string
  end

  -- Find any rate limit counters modified since the last poll.
  --
  -- Note the LEAST() and last_value sequence logic is to handle the edge case
  -- possibility of this sequence value cycling/wrapping once it reaches the
  -- maximum value for bigints. When that happens this sequence is setup to
  -- cycle and start over with negative values. Since the data in this table
  -- expires, there shouldn't be any duplicate version numbers by the time the
  -- sequence cycles.
  --
  -- Loop over results in a cursor to prevent large batches of
  -- changes/insertions from consuming lots of local memory.
  local select_sql = "SELECT id, version, value, extract(epoch FROM expires_at) AS expires_at FROM distributed_rate_limit_counters WHERE version > LEAST(:version, (SELECT last_value - 1 FROM distributed_rate_limit_counters_version_seq)) AND expires_at >= now() ORDER BY version DESC"
  local select_values = { version = last_fetched_version }
  local new_last_fetched_version
  local _, cursor_err = cursor(select_sql, select_values, 1000, { quiet = true }, function(results)
    for _, row in ipairs(results) do
      if not new_last_fetched_version then
        new_last_fetched_version = int64_to_string(row["version"])
      end

      local key = row["id"]
      local distributed_count = row["value"]
      local local_count, local_count_err = counters_dict:get(key)
      if not local_count then
        if local_count_err then
          ngx.log(ngx.ERR, "Error fetching rate limit counter: ", local_count_err)
        end

        local_count = 0
      end

      if distributed_count > local_count then
        local ttl = ceil(row["expires_at"] - current_fetch_time)
        if ttl < 0 then
          ngx.log(ngx.ERR, "distributed_rate_limit_puller ttl unexpectedly less than 0 (key: " .. key .. " ttl: " .. ttl .. ")")
          ttl = 60
        end

        local incr = distributed_count - local_count
        local _, incr_err, incr_forcible = shared_dict_retry_incr(counters_dict, key, incr, 0, ttl)
        if incr_err then
          ngx.log(ngx.ERR, "failed to increment counters shared dict: ", incr_err)
        elseif incr_forcible then
          ngx.log(ngx.WARN, "forcibly set counter in 'rate_limit_counters' shared dict (shared dict may be too small)")
        end
      end
    end
  end)
  if cursor_err then
    ngx.log(ngx.ERR, "cursor error: ", cursor_err)
    return
  end

  if new_last_fetched_version then
    local set_ok, set_err, set_forcible = shared_dict_retry_set(jobs_dict, "rate_limit_counters_store_distributed_last_fetched_version", last_fetched_version)
    if not set_ok then
      ngx.log(ngx.ERR, "failed to set 'rate_limit_counters_store_distributed_last_fetched_version' in 'jobs' shared dict: ", set_err)
    elseif set_forcible then
      ngx.log(ngx.WARN, "forcibly set 'rate_limit_counters_store_distributed_last_fetched_version' in 'jobs' shared dict (shared dict may be too small)")
    end

    set_ok, set_err, set_forcible = shared_dict_retry_set(jobs_dict, "rate_limit_counters_store_distributed_last_pulled_at", current_fetch_time * 1000)
    if not set_ok then
      ngx.log(ngx.ERR, "failed to set 'rate_limit_counters_store_distributed_last_pulled_at' in 'jobs' shared dict: ", set_err)
    elseif set_forcible then
      ngx.log(ngx.WARN, "forcibly set 'rate_limit_counters_store_distributed_last_pulled_at' in 'jobs' shared dict (shared dict may be too small)")
    end
  end
end

return _M
