local Admin = require "api-umbrella.lapis.models.admin"
local capture_errors = require("lapis.application").capture_errors
local db = require "lapis.db"

local db_null = db.NULL

local _M = {}

function _M.new(self)
  return { render = "admin.registrations.new" }
end

function _M.create(self)
  local admin = assert(Admin:create(_M.admin_params(self)))
  local response = {
    admin = admin:as_json(),
  }

  return { redirect_to = "/admin/#/login" }
end

function _M.admin_params(self)
  local params = {}
  if self.params and self.params["admin"] then
    local input = self.params["admin"]
    params = {
      username = input["username"],
      password = input["password"],
      password_confirmation = input["password_confirmation"],

      -- Make the first admin a superuser on initial setup.
      superuser = true,
    }
    ngx.log(ngx.NOTICE, "INPUTS: " .. inspect(params))
  end

  return params
end

return function(app)
  app:get("/admins/signup(.:format)", _M.new)
  app:post("/admins(.:format)", capture_errors({
    on_error = function(self)
      ngx.log(ngx.ERR, "ERRORS: " .. inspect(self.errors))
      return { render = "admin.registrations.new" }
    end,
    _M.create,
  }))
end
