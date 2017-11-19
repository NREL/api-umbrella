local WebsiteBackend = require "api-umbrella.web-app.models.website_backend"
local capture_errors_json = require("api-umbrella.web-app.utils.capture_errors").json
local datatables = require "api-umbrella.web-app.utils.datatables"
local dbify_json_nulls = require "api-umbrella.web-app.utils.dbify_json_nulls"
local json_params = require("lapis.application").json_params
local json_response = require "api-umbrella.web-app.utils.json_response"
local respond_to = require("lapis.application").respond_to
local website_backend_policy = require "api-umbrella.web-app.policies.website_backend_policy"

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

  return { status = 204 }
end

function _M.destroy(self)
  assert(self.website_backend:authorized_delete())

  return { status = 204 }
end

function _M.website_backend_params(self)
  local params = {}
  if self.params and self.params["website_backend"] then
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
    before = function(self)
      self.website_backend = WebsiteBackend:find(self.params["id"])
      if not self.website_backend then
        self:write({"Not Found", status = 404})
      end
    end,
    GET = capture_errors_json(_M.show),
    POST = capture_errors_json(json_params(_M.update)),
    PUT = capture_errors_json(json_params(_M.update)),
    DELETE = capture_errors_json(_M.destroy),
  }))

  app:get("/api-umbrella/v1/website_backends(.:format)", capture_errors_json(_M.index))
  app:post("/api-umbrella/v1/website_backends(.:format)", capture_errors_json(json_params(_M.create)))
end
