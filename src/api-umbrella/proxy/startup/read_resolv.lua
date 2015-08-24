RESOLV_CONF_NAMESERVERS = {}

local stringx = require "pl.stringx"
local types = require "pl.types"

local is_empty = types.is_empty
local strip = stringx.strip

local path = "/etc/resolv.conf"
local file, err = io.open(path, "r")
if err then
  ngx.log(ngx.ERR, "failed to open file: ", err)
else
  for line in file:lines() do
    local nameserver = string.match(line, "^%s*nameserver%s+(.+)$")
    if nameserver then
      nameserver = strip(nameserver)
      if not is_empty(nameserver) then
        table.insert(RESOLV_CONF_NAMESERVERS, nameserver)
      end
    end
  end

  file:close()
end
