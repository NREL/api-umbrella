local _M = {}

local interval_lock = require "api-umbrella.utils.interval_lock"
local pg_utils = require "api-umbrella.utils.pg_utils"

local delay = 60  -- in seconds

local function do_run()
  local queries = {
    "DELETE FROM auto_ssl_storage WHERE expires_at IS NOT NULL AND expires_at < now()",
  }
  for _, query in ipairs(queries) do
    local result, err = pg_utils.query(query, nil, { quiet = true })
    if not result then
      ngx.log(ngx.ERR, "failed to clear expired items: ", err)
    end
  end
end

function _M.spawn()
  interval_lock.repeat_with_mutex('db_expirations', delay, do_run)
end

return _M
