local moses = require "moses"
local inspect = require "inspect"
local distributed_rate_limit_queue = require "distributed_rate_limit_queue"

function blah()
end

return function(settings, user)
  if settings["rate_limit_mode"] == "unlimited" then
    return
  end

  local limits = settings["rate_limits"]
  for _, limit in ipairs(limits) do
    local key = limit["limit_by"] .. "-" .. limit["duration"] .. "-"
    if limit["limit_by"] == "apiKey" then
      key = key .. user["api_key"]
    elseif limit["limit_by"] == "ip" then
      key = key .. ngx.var.remote_addr
    else
      ngx.log(ngx.ERR, "stats unknown limit by")
    end

    local count, err = ngx.shared.stats:incr(key, 1)
    if err == "not found" then
      count = 1
      local success, err = ngx.shared.stats:set(key, count, limit["duration"] / 1000)
      if not success then
        ngx.log(ngx.ERR, "stats set err" .. err)
        return
      end
    elseif err then
      ngx.log(ngx.ERR, "stats incr err" .. err)
      return
    end

    distributed_rate_limit_queue.push(key, limit)

    local remaining = limit["limit"] - count
    ngx.header["X-RateLimit-Limit"] = limit["limit"]
    ngx.header["X-RateLimit-Remaining"] = remaining
    if remaining <= 0 then
      return "over_rate_limit"
    end
  end
end
