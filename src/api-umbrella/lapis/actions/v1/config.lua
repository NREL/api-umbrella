local ApiBackend = require "api-umbrella.lapis.models.api_backend"
local PublishedConfig = require "api-umbrella.lapis.models.published_config"
local WebsiteBackend = require "api-umbrella.lapis.models.website_backend"
local api_backend_policy = require "api-umbrella.lapis.policies.api_backend_policy"
local capture_errors_json = require("api-umbrella.utils.lapis_helpers").capture_errors_json
local json_params = require("lapis.application").json_params
local lapis_json = require "api-umbrella.utils.lapis_json"
local tablex = require "pl.tablex"
local website_backend_policy = require "api-umbrella.lapis.policies.website_backend_policy"

local table_values = tablex.values
local deepcopy = tablex.deepcopy

local _M = {}

function _M.pending_changes(self)
  local active_config = PublishedConfig.active_config() or {}

  local response = {
    config = {
      apis = PublishedConfig.pending_changes_json(active_config["apis"] or {}, ApiBackend, api_backend_policy, self.current_admin),
      website_backends = PublishedConfig.pending_changes_json(active_config["website_backends"] or {}, WebsiteBackend, website_backend_policy, self.current_admin),
    },
  }

  return lapis_json(self, response)
end

local function set_config_for_publishing(self, new_config, category, model)
  if not new_config[category] then
    new_config[category] = {}
  end

  if not self.params["config"] or not self.params["config"][category] then
    return
  end

  local config_by_id = {}
  for _, data in ipairs(new_config[category]) do
    config_by_id[data["id"]] = data
  end

  for record_id, record_params in pairs(self.params["config"][category]) do
    if tostring(record_params["publish"]) ~= "1" then
      break
    end

    local record = model:find(record_id)
    if record then
      config_by_id[record_id] = record:as_json()
    else
      config_by_id[record_id] = nil
    end
  end

  new_config[category] = table_values(config_by_id)
end

function _M.publish(self)
  local active_config = PublishedConfig.active_config() or {}
  local new_config = deepcopy(active_config)

  set_config_for_publishing(self, new_config, "apis", ApiBackend)
  set_config_for_publishing(self, new_config, "website_backends", WebsiteBackend)

  local config = assert(PublishedConfig:create({
    config = new_config,
  }))

  local response = {
    config = config:as_json(),
  }

  self.res.status = 201
  return lapis_json(self, response)
end

return function(app)
  app:get("/api-umbrella/v1/config/pending_changes(.:format)", capture_errors_json(_M.pending_changes))
  app:post("/api-umbrella/v1/config/publish(.:format)", capture_errors_json(json_params(_M.publish)))
end
