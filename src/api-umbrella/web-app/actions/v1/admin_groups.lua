local AdminGroup = require "api-umbrella.web-app.models.admin_group"
local admin_group_policy = require "api-umbrella.web-app.policies.admin_group_policy"
local capture_errors_json = require("api-umbrella.web-app.utils.capture_errors").json
local datatables = require "api-umbrella.web-app.utils.datatables"
local dbify_json_nulls = require "api-umbrella.web-app.utils.dbify_json_nulls"
local json_params = require("lapis.application").json_params
local json_response = require "api-umbrella.web-app.utils.json_response"
local require_admin = require "api-umbrella.web-app.utils.require_admin"
local respond_to = require("lapis.application").respond_to

local _M = {}

function _M.index(self)
  return datatables.index(self, AdminGroup, {
    where = {
      admin_group_policy.authorized_query_scope(self.current_admin),
    },
    search_fields = { "name" },
    preload = {
      "admins",
      "api_scopes",
      "permissions",
    },
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

  return { status = 204 }
end

function _M.destroy(self)
  assert(self.admin_group:authorized_delete())

  return { status = 204 }
end

function _M.admin_group_params(self)
  local params = {}
  if self.params and self.params["admin_group"] then
    local input = self.params["admin_group"]
    params = dbify_json_nulls({
      name = input["name"],
      api_scope_ids = input["api_scope_ids"],
      permission_ids = input["permission_ids"],
    })
    ngx.log(ngx.NOTICE, "INPUTS: " .. inspect(params))
  end

  return params
end

return function(app)
  app:match("/api-umbrella/v1/admin_groups/:id(.:format)", respond_to({
    before = require_admin(function(self)
      self.admin_group = AdminGroup:find(self.params["id"])
      if not self.admin_group then
        self:write({"Not Found", status = 404})
      end
    end),
    GET = capture_errors_json(_M.show),
    POST = capture_errors_json(json_params(_M.update)),
    PUT = capture_errors_json(json_params(_M.update)),
    DELETE = capture_errors_json(_M.destroy),
  }))

  app:get("/api-umbrella/v1/admin_groups(.:format)", require_admin(capture_errors_json(_M.index)))
  app:post("/api-umbrella/v1/admin_groups(.:format)", require_admin(capture_errors_json(json_params(_M.create))))
end
