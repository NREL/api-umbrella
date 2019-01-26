-- Pre-load modules.
require "api-umbrella.proxy.hooks.init_preload_modules"

local worker_group_id = require "api-umbrella.utils.worker_group_id"
worker_group_id.init()

ngx.shared.stats:delete("distributed_last_fetched_at")
ngx.shared.api_users:delete("last_fetched_at")
local set_ok, set_err = ngx.shared.active_config:safe_set("elasticsearch_templates_created", false)
if not set_ok then
  ngx.log(ngx.ERR, "failed to set 'elasticsearch_templates_created' in 'active_config' shared dict: ", set_err)
end
