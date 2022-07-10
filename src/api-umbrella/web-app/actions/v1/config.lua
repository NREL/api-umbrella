local PublishedConfig = require "api-umbrella.web-app.models.published_config"
local capture_errors_json = require("api-umbrella.web-app.utils.capture_errors").json
local csrf_validate_token_or_admin_token_filter = require("api-umbrella.web-app.utils.csrf").validate_token_or_admin_token_filter
local json_response = require "api-umbrella.web-app.utils.json_response"
local require_admin = require "api-umbrella.web-app.utils.require_admin"
local respond_to = require "api-umbrella.web-app.utils.respond_to"
local wrapped_json_params = require "api-umbrella.web-app.utils.wrapped_json_params"

local _M = {}

function _M.pending_changes(self)
  local response = {
    config = PublishedConfig.pending_changes_json(self.current_admin),
  }

  return json_response(self, response)
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
  if type(self.params["config"]) == "table" then
    get_publish_ids(self.params["config"]["apis"], api_backend_ids)
    get_publish_ids(self.params["config"]["website_backends"], website_backend_ids)
  end

  local published_config = PublishedConfig.publish_ids(api_backend_ids, website_backend_ids, self.current_admin)
  local response = {
    config = published_config,
  }

  self.res.status = 201
  return json_response(self, response)
end

return function(app)
  app:match("/api-umbrella/v1/config/pending_changes(.:format)", respond_to({ GET = require_admin(capture_errors_json(_M.pending_changes)) }))
  app:match("/api-umbrella/v1/config/publish(.:format)", respond_to({ POST = csrf_validate_token_or_admin_token_filter(require_admin(capture_errors_json(wrapped_json_params(_M.publish, "config")))) }))
end
