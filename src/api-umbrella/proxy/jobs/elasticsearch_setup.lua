local _M = {}

local cjson = require "cjson"
local http = require "resty.http"
local interval_lock = require "api-umbrella.utils.interval_lock"

local delay = 3600  -- in seconds

local elasticsearch_host = config["elasticsearch"]["hosts"][1]

local function wait_for_elasticsearch()
  local httpc = http.new()
  local elasticsearch_alive = false
  local wait_time = 0
  local sleep_time = 0.5
  local max_time = 60
  repeat
    local res, err = httpc:request_uri(elasticsearch_host .. "/_cluster/health")
    if err then
      ngx.log(ngx.ERR, "failed to fetch cluster health from elasticsearch: ", err)
    elseif res.body then
      local elasticsearch_health = cjson.decode(res.body)
      if elasticsearch_health["status"] == "yellow" or elasticsearch_health["status"] == "green" then
        elasticsearch_alive = true
      end
    end

    if not elasticsearch_alive then
      ngx.sleep(sleep_time)
      wait_time = wait_time + sleep_time
    end
  until elasticsearch_alive or wait_time > max_time
end

local function create_templates()
  -- Template creation only needs to be run once on startup or reload.
  local created = ngx.shared.active_config:get("elasticsearch_templates_created")
  if created then return end

  if elasticsearch_templates then
    local httpc = http.new()
    for _, template in ipairs(elasticsearch_templates) do
      local _, err = httpc:request_uri(elasticsearch_host .. "/_template/" .. template["id"], {
        method = "PUT",
        body = cjson.encode(template["template"]),
      })
      if err then
        ngx.log(ngx.ERR, "failed to update elasticsearch template: ", err)
      end
    end
  end

  ngx.shared.active_config:set("elasticsearch_templates_created", true)
end

local function create_aliases()
  local today = os.date("!%Y-%m", ngx.time())
  local tomorrow = os.date("!%Y-%m", ngx.time() + 86400)

  local aliases = {
    {
      alias = "api-umbrella-logs-" .. today,
      index = "api-umbrella-logs-" .. config["log_template_version"] .. "-" .. today,
    },
    {
      alias = "api-umbrella-logs-write-" .. today,
      index = "api-umbrella-logs-" .. config["log_template_version"] .. "-" .. today,
    },
  }

  -- Create the aliases needed for the next day if we're at the end of the
  -- month.
  if tomorrow ~= today then
    table.insert(aliases, {
      alias = "api-umbrella-logs-" .. tomorrow,
      index = "api-umbrella-logs-" .. config["log_template_version"] .. "-" .. tomorrow,
    })
    table.insert(aliases, {
      alias = "api-umbrella-logs-write-" .. tomorrow,
      index = "api-umbrella-logs-" .. config["log_template_version"] .. "-" .. tomorrow,
    })
  end

  local httpc = http.new()
  for _, alias in ipairs(aliases) do
    -- Make sure the index exists.
    local _, create_err = httpc:request_uri(elasticsearch_host .. "/" .. alias["index"], {
      method = "PUT",
    })
    if create_err then
      ngx.log(ngx.ERR, "failed to create elasticsearch index: ", create_err)
    end

    -- Create the alias for the index.
    local _, alias_err = httpc:request_uri(elasticsearch_host .. "/" .. alias["index"] .. "/_alias/" .. alias["alias"], {
      method = "PUT",
    })
    if alias_err then
      ngx.log(ngx.ERR, "failed to create elasticsearch index alias: ", alias_err)
    end
  end
end

local function do_check()
  wait_for_elasticsearch()
  create_templates()
  create_aliases()
end

function _M.spawn()
  interval_lock.repeat_with_mutex('elasticsearch_index_setup', delay, do_check)
end

return _M
