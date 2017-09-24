local PublishedConfig = require "api-umbrella.lapis.models.published_config"
local capture_errors_json = require("api-umbrella.utils.lapis_helpers").capture_errors_json
local json_params = require("lapis.application").json_params
local lapis_json = require "api-umbrella.utils.lapis_json"

local _M = {}

function _M.pending_changes(self)
  local response = {
    config = PublishedConfig.pending_changes_json(self.current_admin),
  }

  return lapis_json(self, response)
end

local function get_publish_ids(params, ids)
  if params then
    for record_id, record_params in pairs(params) do
      if tostring(record_params["publish"]) == "1" then
        table.insert(ids, record_id)
      end
    end
  end
end

function _M.publish(self)
  local api_backend_ids = {}
  local website_backend_ids = {}
  if self.params["config"] then
    get_publish_ids(self.params["config"]["apis"], api_backend_ids)
    get_publish_ids(self.params["config"]["website_backends"], website_backend_ids)
  end

  local published_config = PublishedConfig.publish_ids(api_backend_ids, website_backend_ids, self.current_admin)
  local response = {
    config = published_config,
  }

  self.res.status = 201
  return lapis_json(self, response)
end

return function(app)
  app:get("/api-umbrella/v1/config/pending_changes(.:format)", capture_errors_json(_M.pending_changes))
  app:post("/api-umbrella/v1/config/publish(.:format)", capture_errors_json(json_params(_M.publish)))
end
