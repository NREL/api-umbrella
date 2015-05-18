DEBUG = false

local load_config = require "load_config"
config = load_config.parse()

ngx.shared.apis:set("config_id", config["config_id"])
ngx.shared.apis:set("upstreams_inited", false)
ngx.shared.apis:delete("nginx_reloading_guard")
ngx.shared.apis:delete("version")
ngx.shared.apis:delete("last_fetched_at")

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

MASTER_NODE_ID = master_id
