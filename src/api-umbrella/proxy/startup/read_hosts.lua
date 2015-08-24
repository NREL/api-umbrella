local plutils = require "pl.utils"
local stringx = require "pl.stringx"
local types = require "pl.types"

local is_empty = types.is_empty
local split = plutils.split
local strip = stringx.strip

ETC_HOSTS = {}

local path = "/etc/hosts"
local file, err = io.open(path, "r")
if err then
  ngx.log(ngx.ERR, "failed to open file: ", err)
else
  for line in file:lines() do
    local parts = split(line, "%s+", false, 2)
    if parts then
      local ip = parts[1]
      local hosts = parts[2]
      if ip and hosts then
        ip = strip(ip)
        hosts = split(strip(hosts), "%s+")
        if not is_empty(ip) and not is_empty(hosts) then
          for _, host in ipairs(hosts) do
            ETC_HOSTS[host] = ip
          end
        end
      end
    end
  end

  file:close()
end
