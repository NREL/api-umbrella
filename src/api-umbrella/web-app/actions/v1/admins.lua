local Admin = require "api-umbrella.web-app.models.admin"
local admin_policy = require "api-umbrella.web-app.policies.admin_policy"
local capture_errors_json_full = require("api-umbrella.web-app.utils.capture_errors").json_full
local datatables = require "api-umbrella.web-app.utils.datatables"
local dbify_json_nulls = require "api-umbrella.web-app.utils.dbify_json_nulls"
local json_params = require("lapis.application").json_params
local json_response = require "api-umbrella.web-app.utils.json_response"
local require_admin = require "api-umbrella.web-app.utils.require_admin"
local respond_to = require("lapis.application").respond_to

local _M = {}

function _M.index(self)
  return datatables.index(self, Admin, {
    where = {
      admin_policy.authorized_query_scope(self.current_admin),
    },
    search_fields = {
      "name",
      "email",
      "username",
    },
    preload = { "groups" },
  })
end

function _M.show(self)
  self.admin:authorize()
  local response = {
    admin = self.admin:as_json(),
  }

  return json_response(self, response)
end

function _M.create(self)
  local admin = assert(Admin:authorized_create(_M.admin_params(self)))
  local response = {
    admin = admin:as_json(),
  }

  self.res.status = 201
  return json_response(self, response)
end

function _M.update(self)
  self.admin:authorized_update(_M.admin_params(self))
  local response = {
    admin = self.admin:as_json(),
  }

  self.res.status = 200
  return json_response(self, response)
end

function _M.destroy(self)
  assert(self.admin:authorized_delete())

  return { status = 204 }
end

function _M.admin_params(self)
  local params = {}
  if self.params and self.params["admin"] then
    local input = self.params["admin"]
    params = dbify_json_nulls({
      username = input["username"],
      password = input["password"],
      password_confirmation = input["password_confirmation"],
      current_password = input["current_password"],
      email = input["email"],
      name = input["name"],
      notes = input["notes"],
      superuser = input["superuser"],
      group_ids = input["group_ids"],
    })

    -- Only allow the current admin to update their own password. For creates
    -- we assume that invites are sent with a password reset e-mail link.
    if not self.admin or not self.current_admin or self.admin.id ~= self.current_admin.id then
      params["password"] = nil
      params["password_confirmation"] = nil
      params["current_password"] = nil
    end
  end

  return params
end

return function(app)
  app:match("/api-umbrella/v1/admins/:id(.:format)", respond_to({
    before = require_admin(function(self)
      self.admin = Admin:find(self.params["id"])
      if not self.admin then
        self:write({"Not Found", status = 404})
      end
    end),
    GET = capture_errors_json_full(_M.show),
    POST = capture_errors_json_full(json_params(_M.update)),
    PUT = capture_errors_json_full(json_params(_M.update)),
    DELETE = capture_errors_json_full(_M.destroy),
  }))

  app:get("/api-umbrella/v1/admins(.:format)", require_admin(capture_errors_json_full(_M.index)))
  app:post("/api-umbrella/v1/admins(.:format)", require_admin(capture_errors_json_full(json_params(_M.create))))
end
