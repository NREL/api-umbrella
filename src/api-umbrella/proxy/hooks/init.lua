DEBUG = false

local load_config = require "api-umbrella.proxy.load_config"
config = load_config.parse()

require "api-umbrella.proxy.startup.init_elasticsearch_templates_data"
require "api-umbrella.proxy.startup.init_user_agent_parser_data"

ngx.shared.apis:set("config_id", config["config_id"])
ngx.shared.apis:delete("nginx_reloading_guard")
ngx.shared.apis:delete("version")
ngx.shared.apis:delete("last_fetched_at")
ngx.shared.upstream_checksums:flush_all()
ngx.shared.stats:delete("distributed_last_fetched_at")
ngx.shared.api_users:delete("last_fetched_at")
ngx.shared.config:set("elasticsearch_templates_created", false)

-- Generate a unique ID to represent this group of worker processes. This value
-- will be the same amongst all the subsequently inited workers, but the value
-- will differ for each new group of worker processes that get started when
-- nginx is reloaded (SIGHUP).
--
-- This is used to prevent race conditions in the dyups module so that we can
-- properly know when upstreams are setup after nginx is reloaded.
local random = require "resty.random"
local str = require "resty.string"
WORKER_GROUP_ID = str.to_hex(random.bytes(8))
