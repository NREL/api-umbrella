local interval_lock = require "api-umbrella.utils.interval_lock"
local opensearch = require "api-umbrella.utils.opensearch"
local opensearch_templates = require "api-umbrella.proxy.opensearch_templates_data"

local opensearch_query = opensearch.query
local jobs_dict = ngx.shared.jobs
local sleep = ngx.sleep

local delay = 3600  -- in seconds

local _M = {}

function _M.wait_for_opensearch()
  local opensearch_alive = false
  local wait_time = 0
  local sleep_time = 0.5
  local max_time = 60
  repeat
    local res, err = opensearch_query("/_cluster/health")
    if err then
      ngx.log(ngx.NOTICE, "failed to fetch cluster health from opensearch (this is expected if opensearch is starting up at the same time): ", err)
    elseif res.body_json and res.body_json["status"] == "yellow" or res.body_json["status"] == "green" then
      opensearch_alive = true
    end

    if not opensearch_alive then
      sleep(sleep_time)
      wait_time = wait_time + sleep_time
    end
  until opensearch_alive or wait_time > max_time

  if opensearch_alive then
    return true, nil
  else
    return false, "opensearch was not ready within " .. max_time  .."s"
  end
end

function _M.create_templates()
  -- Template creation only needs to be run once on startup or reload.
  local created = jobs_dict:get("opensearch_templates_created")
  if created then return end

  if opensearch_templates then
    for template_id, template in pairs(opensearch_templates) do
      local _, err = opensearch_query("/_index_template/" .. template_id, {
        method = "PUT",
        body = template,
      })
      if err then
        ngx.log(ngx.ERR, "failed to update opensearch template: ", err)
      end
    end
  end

  local set_ok, set_err = jobs_dict:safe_set("opensearch_templates_created", true)
  if not set_ok then
    ngx.log(ngx.ERR, "failed to set 'opensearch_templates_created' in 'active_config' shared dict: ", set_err)
  end
end

local function setup()
  local _, err = _M.wait_for_opensearch()
  if not err then
    _M.create_templates()
  else
    ngx.log(ngx.ERR, "timed out waiting for eleasticsearch before setup, rerunning...")
    sleep(5)
    setup()
  end
end

function _M.spawn()
  interval_lock.repeat_with_mutex('opensearch_index_setup', delay, setup)
end

return _M
