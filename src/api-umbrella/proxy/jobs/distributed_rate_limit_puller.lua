local _M = {}

local int64 = require "api-umbrella.utils.int64"
local interval_lock = require "api-umbrella.utils.interval_lock"
local pg_utils = require "api-umbrella.utils.pg_utils"

local delay = 0.25  -- in seconds

local function do_check()
  local current_fetch_time = ngx.now()
  local last_fetched_version = ngx.shared.stats:get("distributed_last_fetched_version") or int64.MIN_VALUE_STRING

  -- Find any rate limit counters modified since the last poll.
  --
  -- Note the LEAST() and last_value sequence logic is to handle the edge case
  -- possibility of this sequence value cycling/wrapping once it reaches the
  -- maximum value for bigints. When that happens this sequence is setup to
  -- cycle and start over with negative values. Since the data in this table
  -- expires, there shouldn't be any duplicate version numbers by the time the
  -- sequence cycles.
  local results, err = pg_utils.query("SELECT id, version, value, extract(epoch FROM expires_at) AS expires_at FROM distributed_rate_limit_counters WHERE version > LEAST($1, (SELECT last_value - 1 FROM distributed_rate_limit_counters_version_seq)) ORDER BY version DESC", last_fetched_version)
  if not results then
    ngx.log(ngx.ERR, "failed to fetch rate limits from database: ", err)
    return nil
  end

  for index, row in ipairs(results) do
    if index == 1 then
      last_fetched_version = int64.to_string(row["version"])
    end

    local key = row["id"]
    local distributed_count = row["value"]
    local local_count = ngx.shared.stats:get(key)
    if not local_count then
      if row["expires_at"] then
        local ttl = row["expires_at"] - current_fetch_time
        if ttl < 0 then
          ngx.log(ngx.ERR, "distributed_rate_limit_puller ttl unexpectedly less than 0 (key: " .. key .. " ttl: " .. ttl .. ")")
          ttl = 3600
        end

        local set_ok, set_err, set_forcible = ngx.shared.stats:set(key, tonumber(distributed_count), ttl)
        if not set_ok then
          ngx.log(ngx.ERR, "failed to set rate limit key in 'stats' shared dict: ", set_err)
        elseif set_forcible then
          ngx.log(ngx.WARN, "forcibly set rate limit key in 'stats' shared dict (shared dict may be too small)")
        end
      end
    elseif distributed_count > local_count then
      local incr = distributed_count - local_count
      local _, incr_err = ngx.shared.stats:incr(key, tonumber(incr))
      if incr_err then
        ngx.log(ngx.ERR, "failed to increment rate limit key: ", incr_err)
      end
    end
  end

  local set_ok, set_err, set_forcible = ngx.shared.stats:set("distributed_last_fetched_version", last_fetched_version)
  if not set_ok then
    ngx.log(ngx.ERR, "failed to set 'distributed_last_fetched_version' in 'stats' shared dict: ", set_err)
  elseif set_forcible then
    ngx.log(ngx.WARN, "forcibly set 'distributed_last_fetched_version' in 'stats' shared dict (shared dict may be too small)")
  end

  set_ok, set_err, set_forcible = ngx.shared.stats:set("distributed_last_pulled_at", current_fetch_time * 1000)
  if not set_ok then
    ngx.log(ngx.ERR, "failed to set 'distributed_last_pulled_at' in 'stats' shared dict: ", set_err)
  elseif set_forcible then
    ngx.log(ngx.WARN, "forcibly set 'distributed_last_pulled_at' in 'stats' shared dict (shared dict may be too small)")
  end
end

function _M.spawn()
  interval_lock.repeat_with_mutex('distributed_rate_limit_puller', delay, do_check)
end

return _M
