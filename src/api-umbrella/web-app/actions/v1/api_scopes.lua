local ApiScope = require "api-umbrella.web-app.models.api_scope"
local api_scope_policy = require "api-umbrella.web-app.policies.api_scope_policy"
local capture_errors_json = require("api-umbrella.web-app.utils.capture_errors").json
local csrf_validate_token_or_admin_token_filter = require("api-umbrella.web-app.utils.csrf").validate_token_or_admin_token_filter
local datatables = require "api-umbrella.web-app.utils.datatables"
local dbify_json_nulls = require "api-umbrella.web-app.utils.dbify_json_nulls"
local json_response = require "api-umbrella.web-app.utils.json_response"
local require_admin = require "api-umbrella.web-app.utils.require_admin"
local respond_to = require "api-umbrella.web-app.utils.respond_to"
local validation_ext = require "api-umbrella.web-app.utils.validation_ext"
local wrapped_json_params = require "api-umbrella.web-app.utils.wrapped_json_params"

local _M = {}

function _M.index(self)
  if not self.params["order"] and not self.params["columns"] then
    self.params["columns"] = {
      ["0"] = {
        data = "name",
      }
    }

    self.params["order"] = {
      ["0"] = {
        column = "0",
        dir = "asc",
      },
    }
  end

  return datatables.index(self, ApiScope, {
    where = {
      api_scope_policy.authorized_query_scope(self.current_admin),
    },
    search_fields = {
      "name",
      "host",
      "path_prefix",
    },
    order_fields = {
      "name",
      "host",
      "path_prefix",
      "created_at",
      "updated_at",
    },
    preload = {
      "admin_groups",
      "api_backends",
    },
    csv_filename = "api_scopes",
  })
end

function _M.show(self)
  self.api_scope:authorize()
  local response = {
    api_scope = self.api_scope:as_json(),
  }

  return json_response(self, response)
end

function _M.create(self)
  local api_scope = assert(ApiScope:authorized_create(_M.api_scope_params(self)))
  local response = {
    api_scope = api_scope:as_json(),
  }

  self.res.status = 201
  return json_response(self, response)
end

function _M.update(self)
  self.api_scope:authorized_update(_M.api_scope_params(self))

  return { status = 204, layout = false }
end

function _M.destroy(self)
  assert(self.api_scope:authorized_delete())

  return { status = 204, layout = false }
end

function _M.api_scope_params(self)
  local params = {}
  if self.params and type(self.params["api_scope"]) == "table" then
    local input = self.params["api_scope"]
    params = dbify_json_nulls({
      name = input["name"],
      host = input["host"],
      path_prefix = input["path_prefix"],
    })
  end

  return params
end

return function(app)
  app:match("/api-umbrella/v1/api_scopes/:id(.:format)", respond_to({
    before = require_admin(function(self)
      local ok = validation_ext.string.uuid(self.params["id"])
      if ok then
        self.api_scope = ApiScope:find(self.params["id"])
      end
      if not self.api_scope then
        return self.app.handle_404(self)
      end
    end),
    GET = capture_errors_json(_M.show),
    POST = csrf_validate_token_or_admin_token_filter(capture_errors_json(wrapped_json_params(_M.update, "api_scope"))),
    PUT = csrf_validate_token_or_admin_token_filter(capture_errors_json(wrapped_json_params(_M.update, "api_scope"))),
    DELETE = csrf_validate_token_or_admin_token_filter(capture_errors_json(_M.destroy)),
  }))

  app:match("/api-umbrella/v1/api_scopes(.:format)", respond_to({
    before = require_admin(),
    GET = capture_errors_json(_M.index),
    POST = csrf_validate_token_or_admin_token_filter(capture_errors_json(wrapped_json_params(_M.create, "api_scope"))),
  }))
end
