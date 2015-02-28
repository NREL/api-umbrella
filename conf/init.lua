DEBUG = false

local load_config = require "load_config"
config = load_config.parse()
config_version = ngx.now()
ngx.shared.apis:set("config_version", config_version)

local unistd = require "posix.unistd"
local utsname = require "posix.sys.utsname"
local resty_random = require "resty.random"
local str = require "resty.string"

local master_id = utsname.uname()["nodename"]
if DEBUG then
  master_id = master_id .. "-" .. unistd.getppid()
else
  master_id = master_id .. "-" .. unistd.getpid()
  master_id = master_id .. "-" .. str.to_hex(resty_random.bytes(4))
end

-- Require the module
local ledge_m = require "ledge.ledge"

-- Create a global instance and set any global configuration
ledge = ledge_m.new()
-- ledge:config_set("use_resty_upstream", true)
ledge:config_set("enable_collapsed_forwarding", true)
ledge:config_set("redis_host", { host = "127.0.0.1", port = 13000 })
ledge:config_set("upstream_host", "127.0.0.1")
ledge:config_set("upstream_port", 9999)

MASTER_NODE_ID = master_id
