local _M = {}

local api_store = require "api-umbrella.proxy.api_store"
local dyups = require "ngx.dyups"
local http = require "resty.http"
local inspect = require "inspect"
local plutils = require "pl.utils"
local types = require "pl.types"

local is_empty = types.is_empty
local split = plutils.split

local upstream_checksums = {}

function _M.setup_backends(apis)
  local upstreams_changed = false
  for _, api in ipairs(apis) do
    local upstream = ""

    local balance = api["balance_algorithm"]
    if balance == "least_conn" or balance == "least_conn" then
      upstream = upstream .. balance .. ";\n"
    end

    local keepalive = api["keepalive_connections"] or 10
    upstream = upstream .. "keepalive " .. keepalive .. ";\n"

    local servers = {}
    if api["servers"] then
      for _, server in ipairs(api["servers"]) do
        local ips = nil
        local m, err = ngx.re.match(server["host"], "^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$")
        if m then
          ips = server["host"]
        else
          ips = ngx.shared.resolved_hosts:get(server["host"])
        end

        if ips and server["port"] then
          ips = split(ips, ",", true)
          for _, ip in ipairs(ips) do
            table.insert(servers, "server " .. ip .. ":" .. server["port"] .. ";")
          end
        end
      end
    end

    if is_empty(servers) then
      table.insert(servers, "server 127.255.255.255:80 down;")
    end

    upstream = upstream .. table.concat(servers, "\n") .. "\n"

    local backend_id = "api_umbrella_" .. api["_id"] .. "_backend"

    -- Only apply the upstream if it differs from the upstream currently
    -- installed. Since we're looping over all the APIs, this just helps
    -- prevent unnecessary upstream changes when only a single upstream has
    -- changed.
    --
    -- Note that the cache of current upstream checksums would ideally be a
    -- ngx.shared table, but instead it's a local table. So this means there
    -- will initially be some duplicate changes across each worker process the
    -- first time an upstream is seen. But this helps prevent race conditions
    -- with nginx is being reloaded and new processes are being started, so for
    -- now I think this is fine.
    --
    -- TODO: balancer_by_lua is supposedly coming soon, which I think might
    -- offer a much cleaner way to deal with all this versus what we're
    -- currently doing with dyups. Revisit if that gets released.
    -- https://groups.google.com/d/msg/openresty-en/NS2dWt-xHsY/PYzi5fiiW8AJ
    local upstream_checksum = ngx.md5(upstream)
    local current_upstream_checksum = upstream_checksums[backend_id]
    if(upstream_checksum ~= current_upstream_checksum) then
      upstreams_changed = true

      -- Apply the new backend with dyups. If dyups is locked, keep trying
      -- until we succeed or time out.
      local update_suceeded = false
      local wait_time = 0
      local sleep_time = 0.01
      local max_time = 5
      repeat
        local status, rv = dyups.update(backend_id, upstream);
        if status == 200 then
          update_suceeded = true
        else
          ngx.sleep(sleep_time)
          wait_time = wait_time + sleep_time
        end
      until update_suceeded or wait_time > max_time

      if not update_suceeded then
        ngx.log(ngx.ERR, "Failed to setup upstream for " .. backend_id .. ". Trying to continue anyway...")
      end

      upstream_checksums[backend_id] = upstream_checksum
    end
  end

  -- After making changes to the upstreams with dyups, we have to wait for
  -- those changes to actually be read and applied to all the individual worker
  -- processes. So wait a bit more than what dyups_read_msg_timeout is
  -- configured to be.
  --
  -- We wait here so that we can better ensure that once setup_backends()
  -- finishes, then the updates should actually be in effect (which we use for
  -- knowing when config changes are in place in the /api-umbrella/v1/state
  -- API).
  if upstreams_changed then
    ngx.sleep(0.7)
  end
end

return _M
