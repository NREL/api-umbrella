-- Pre-load modules.
require "api-umbrella.proxy.hooks.init_preload_modules"

local jobs_dict = ngx.shared.jobs

local set_ok, set_err = jobs_dict:safe_set("elasticsearch_templates_created", false)
if not set_ok then
  ngx.log(ngx.ERR, "failed to set 'elasticsearch_templates_created' in 'active_config' shared dict: ", set_err)
end
