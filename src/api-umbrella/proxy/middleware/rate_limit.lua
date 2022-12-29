local rate_limit_check = require("api-umbrella.proxy.stores.rate_limit_counters_store").check

return function(api, settings, user, remote_addr)
  local exceeded, header_limit, header_remaining, header_retry_after = rate_limit_check(api, settings, user, remote_addr)

  if header_limit then
    ngx.header["X-RateLimit-Limit"] = header_limit
  end

  if header_remaining then
    ngx.header["X-RateLimit-Remaining"] = header_remaining
  end

  if header_retry_after then
    ngx.header["Retry-After"] = header_retry_after
  end

  if exceeded then
    return "over_rate_limit"
  end
end
