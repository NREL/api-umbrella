local Admin = require "api-umbrella.lapis.models.admin"
local admin_policy = require "api-umbrella.lapis.policies.admin_policy"
local capture_errors_json_full = require("api-umbrella.utils.lapis_helpers").capture_errors_json_full
local dbify_json_nulls = require "api-umbrella.utils.dbify_json_nulls"
local json_params = require("lapis.application").json_params
local lapis_datatables = require "api-umbrella.utils.lapis_datatables"
local lapis_json = require "api-umbrella.utils.lapis_json"
local respond_to = require("lapis.application").respond_to

local _M = {}

function _M.index(self)
  return lapis_datatables.index(self, Admin, {
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

  return lapis_json(self, response)
end

function _M.create(self)
  local admin = assert(Admin:authorized_create(_M.admin_params(self)))
  local response = {
    admin = admin:as_json(),
  }

  self.res.status = 201
  return lapis_json(self, response)
end

function _M.update(self)
  self.admin:authorized_update(_M.admin_params(self))
  local response = {
    admin = self.admin:as_json(),
  }

  self.res.status = 200
  return lapis_json(self, response)
end

function _M.destroy(self)
  self.admin:authorize()
  assert(self.admin:delete())

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
    before = function(self)
      self.admin = Admin:find(self.params["id"])
      if not self.admin then
        self:write({"Not Found", status = 404})
      end
    end,
    GET = capture_errors_json_full(_M.show),
    POST = capture_errors_json_full(json_params(_M.update)),
    PUT = capture_errors_json_full(json_params(_M.update)),
    DELETE = capture_errors_json_full(_M.destroy),
  }))

  app:get("/api-umbrella/v1/admins(.:format)", capture_errors_json_full(_M.index))
  app:post("/api-umbrella/v1/admins(.:format)", capture_errors_json_full(json_params(_M.create)))
end
