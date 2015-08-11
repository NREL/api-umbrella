local inspect = require "inspect"

local upstreams_setup_complete = false

return function()
  -- When nginx is first starting or the workers are being reloaded (SIGHUP),
  -- pause the request serving until the API config and upstreams have been
  -- configured. This prevents temporary 404s (api config not yet fetched) or bad
  -- gateway errors (upstreams not yet configured) during startup or reloads.
  --
  -- TODO: balancer_by_lua is supposedly coming soon, which I think might offer a
  -- much cleaner way to deal with all this versus what we're currently doing
  -- with dyups. Revisit if that gets released.
  -- https://groups.google.com/d/msg/openresty-en/NS2dWt-xHsY/PYzi5fiiW8AJ
  if upstreams_setup_complete then
    return
  end

  upstreams_setup_complete = ngx.shared.active_config:get("upstreams_setup_complete:" .. WORKER_GROUP_ID)
  if not upstreams_setup_complete then
    local wait_time = 0
    local sleep_time = 0.1
    local max_time = 15
    repeat
      ngx.sleep(sleep_time)
      wait_time = wait_time + sleep_time
      upstreams_setup_complete = ngx.shared.active_config:get("upstreams_setup_complete:" .. WORKER_GROUP_ID)
    until upstreams_setup_complete or wait_time > max_time

    -- This really shouldn't happen, but if things don't appear to be
    -- initializing properly within a reasonable amount of time, log the error
    -- and try continuing anyway.
    if not upstreams_setup_complete then
      ngx.log(ngx.ERR, "Failed to initialize config or upstreams within expected time. Trying to continue anyway...")
    end
  end
end
