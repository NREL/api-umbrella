DEBUG = false

inspect = require "inspect"

-- Generate a unique ID to represent this group of worker processes. This value
-- will be the same amongst all the subsequently inited workers, but the value
-- will differ for each new group of worker processes that get started when
-- nginx is reloaded (SIGHUP).
--
-- This is used to prevent race conditions in the dyups module so that we can
-- properly know when upstreams are setup after nginx is reloaded.
WORKER_GROUP_ID, err = ngx.shared.active_config:incr("worker_group_id", 1)
if err == "not found" then
  WORKER_GROUP_ID = 1
  local success, err = ngx.shared.active_config:set("worker_group_id", 1)
  if not success then
    ngx.log(ngx.ERR, "worker_group_id set err: ", err)
    return
  end
elseif err then
  ngx.log(ngx.ERR, "worker_group_id incr err: ", err)
end

config = require "api-umbrella.proxy.models.file_config"

require "api-umbrella.proxy.startup.init_elasticsearch_templates_data"
require "api-umbrella.proxy.startup.init_user_agent_parser_data"

ngx.shared.upstream_checksums:flush_all()
ngx.shared.stats:delete("distributed_last_fetched_at")
ngx.shared.api_users:delete("last_fetched_at")
ngx.shared.config:set("elasticsearch_templates_created", false)
