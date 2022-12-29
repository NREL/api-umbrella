local WebsiteBackend = require "api-umbrella.web-app.models.website_backend"
local csrf_validate_token_or_admin_token_filter = require("api-umbrella.web-app.utils.csrf").validate_token_or_admin_token_filter
local capture_errors_json = require("api-umbrella.web-app.utils.capture_errors").json
local datatables = require "api-umbrella.web-app.utils.datatables"
local dbify_json_nulls = require "api-umbrella.web-app.utils.dbify_json_nulls"
local json_response = require "api-umbrella.web-app.utils.json_response"
local require_admin = require "api-umbrella.web-app.utils.require_admin"
local respond_to = require "api-umbrella.web-app.utils.respond_to"
local validation_ext = require "api-umbrella.web-app.utils.validation_ext"
local website_backend_policy = require "api-umbrella.web-app.policies.website_backend_policy"
local wrapped_json_params = require "api-umbrella.web-app.utils.wrapped_json_params"

local _M = {}

function _M.index(self)
  return datatables.index(self, WebsiteBackend, {
    where = {
      website_backend_policy.authorized_query_scope(self.current_admin),
    },
    search_fields = {
      "frontend_host",
      "server_host",
    },
    order_fields = {
      "frontend_host",
      "created_at",
      "updated_at",
    },
    csv_filename = "website_backends",
  })
end

function _M.show(self)
  self.website_backend:authorize()
  local response = {
    website_backend = self.website_backend:as_json(),
  }

  return json_response(self, response)
end

function _M.create(self)
  local website_backend = assert(WebsiteBackend:authorized_create(_M.website_backend_params(self)))
  local response = {
    website_backend = website_backend:as_json(),
  }

  self.res.status = 201
  return json_response(self, response)
end

function _M.update(self)
  self.website_backend:authorized_update(_M.website_backend_params(self))

  return { status = 204, layout = false }
end

function _M.destroy(self)
  assert(self.website_backend:authorized_delete())

  return { status = 204, layout = false }
end

function _M.website_backend_params(self)
  local params = {}
  if self.params and type(self.params["website_backend"]) == "table" then
    local input = self.params["website_backend"]
    params = dbify_json_nulls({
      frontend_host = input["frontend_host"],
      backend_protocol = input["backend_protocol"],
      server_host = input["server_host"],
      server_port = input["server_port"],
    })
  end

  return params
end

return function(app)
  app:match("/api-umbrella/v1/website_backends/:id(.:format)", respond_to({
    before = require_admin(function(self)
      local ok = validation_ext.string.uuid(self.params["id"])
      if ok then
        self.website_backend = WebsiteBackend:find(self.params["id"])
      end
      if not self.website_backend then
        return self.app.handle_404(self)
      end
    end),
    GET = capture_errors_json(_M.show),
    POST = csrf_validate_token_or_admin_token_filter(capture_errors_json(wrapped_json_params(_M.update, "website_backend"))),
    PUT = csrf_validate_token_or_admin_token_filter(capture_errors_json(wrapped_json_params(_M.update, "website_backend"))),
    DELETE = csrf_validate_token_or_admin_token_filter(capture_errors_json(_M.destroy)),
  }))

  app:match("/api-umbrella/v1/website_backends(.:format)", respond_to({
    before = require_admin(),
    GET = capture_errors_json(_M.index),
    POST = csrf_validate_token_or_admin_token_filter(capture_errors_json(wrapped_json_params(_M.create, "website_backend"))),
  }))
end
