local _M = {}

local array_last = require "api-umbrella.utils.array_last"
local distributed_rate_limit_queue = require "api-umbrella.proxy.distributed_rate_limit_queue"
local pg_utils = require "api-umbrella.utils.pg_utils"
local plutils = require "pl.utils"
local types = require "pl.types"
local xpcall_error_handler = require "api-umbrella.utils.xpcall_error_handler"

local is_empty = types.is_empty
local split = plutils.split

local delay = 0.25  -- in seconds
local new_timer = ngx.timer.at

local function do_check()
  local current_save_time = ngx.now()

  local data = distributed_rate_limit_queue.pop()
  if is_empty(data) then
    return
  end

  local success = true
  for key, count in pairs(data) do
    local key_parts = split(key, ":", true)
    local duration = tonumber(key_parts[2])
    local bucket_start_time = tonumber(array_last(key_parts))
    local expires_at = (bucket_start_time + duration + 60000) / 1000

    local result, err = pg_utils.query("INSERT INTO distributed_rate_limit_counters(id, value, expires_at) VALUES($1, $2, to_timestamp($3)) ON CONFLICT (id) DO UPDATE SET value = distributed_rate_limit_counters.value + EXCLUDED.value", key, count, expires_at)
    if not result then
      ngx.log(ngx.ERR, "failed to update rate limits in database: ", err)
      success = false
    end
  end

  if success then
    local set_ok, set_err, set_forcible = ngx.shared.stats:set("distributed_last_pushed_at", current_save_time * 1000)
    if not set_ok then
      ngx.log(ngx.ERR, "failed to set 'distributed_last_pushed_at' in 'stats' shared dict: ", set_err)
    elseif set_forcible then
      ngx.log(ngx.WARN, "forcibly set 'distributed_last_pushed_at' in 'stats' shared dict (shared dict may be too small)")
    end
  end
end

-- Repeat calls to do_check() inside each worker on the specified interval
-- (every 0.25 seconds).
--
-- We don't use interval_lock.repeat_with_mutex() here like most of our other
-- background jobs, because in this job's case we're pushing local worker data
-- into the database. In this case, we don't want a mutex across workers, since
-- we want each worker to operate independently and fire every 0.25 seconds to
-- push it's local data to the database. With a mutex, certain workers may not
-- be called for longer periods of time causing the local data to build up and
-- not be synced as frequently as we expect.
local function check(premature)
  if premature then
    return
  end

  local ok, err = xpcall(do_check, xpcall_error_handler)
  if not ok then
    ngx.log(ngx.ERR, "failed to run backend load cycle: ", err)
  end

  ok, err = new_timer(delay, check)
  if not ok then
    if err ~= "process exiting" then
      ngx.log(ngx.ERR, "failed to create timer: ", err)
    end

    return
  end
end

function _M.spawn()
  local ok, err = new_timer(0, check)
  if not ok then
    ngx.log(ngx.ERR, "failed to create timer: ", err)
    return
  end
end

return _M
