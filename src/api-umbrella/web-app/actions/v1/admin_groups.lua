local AdminGroup = require "api-umbrella.web-app.models.admin_group"
local admin_group_policy = require "api-umbrella.web-app.policies.admin_group_policy"
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

  return datatables.index(self, AdminGroup, {
    where = {
      admin_group_policy.authorized_query_scope(self.current_admin),
    },
    search_fields = {
      "name",
    },
    order_fields = {
      "name",
      "created_at",
      "updated_at",
    },
    preload = {
      "admins",
      "api_scopes",
      "permissions",
    },
    csv_filename = "admin_groups",
  })
end

function _M.show(self)
  self.admin_group:authorize()
  local response = {
    admin_group = self.admin_group:as_json(),
  }

  return json_response(self, response)
end

function _M.create(self)
  local admin_group = assert(AdminGroup:authorized_create(_M.admin_group_params(self)))
  local response = {
    admin_group = admin_group:as_json(),
  }

  self.res.status = 201
  return json_response(self, response)
end

function _M.update(self)
  self.admin_group:authorized_update(_M.admin_group_params(self))

  return { status = 204, layout = false }
end

function _M.destroy(self)
  assert(self.admin_group:authorized_delete())

  return { status = 204, layout = false }
end

function _M.admin_group_params(self)
  local params = {}
  if self.params and type(self.params["admin_group"]) == "table" then
    local input = self.params["admin_group"]
    params = dbify_json_nulls({
      name = input["name"],
      api_scope_ids = input["api_scope_ids"],
      permission_ids = input["permission_ids"],
    })
  end

  return params
end

return function(app)
  app:match("/api-umbrella/v1/admin_groups/:id(.:format)", respond_to({
    before = require_admin(function(self)
      local ok = validation_ext.string.uuid(self.params["id"])
      if ok then
        self.admin_group = AdminGroup:find(self.params["id"])
      end
      if not self.admin_group then
        return self.app.handle_404(self)
      end
    end),
    GET = capture_errors_json(_M.show),
    POST = csrf_validate_token_or_admin_token_filter(capture_errors_json(wrapped_json_params(_M.update, "admin_group"))),
    PUT = csrf_validate_token_or_admin_token_filter(capture_errors_json(wrapped_json_params(_M.update, "admin_group"))),
    DELETE = csrf_validate_token_or_admin_token_filter(capture_errors_json(_M.destroy)),
  }))

  app:match("/api-umbrella/v1/admin_groups(.:format)", respond_to({
    before = require_admin(),
    GET = capture_errors_json(_M.index),
    POST = csrf_validate_token_or_admin_token_filter(capture_errors_json(wrapped_json_params(_M.create, "admin_group"))),
  }))
end
