local Admin = require "api-umbrella.lapis.models.admin"
local respond_to = require("lapis.application").respond_to
local _ = require("resty.gettext").gettext
local capture_errors = require("lapis.application").capture_errors
local db = require "lapis.db"

local db_null = db.NULL

local _M = {}

function _M.new(self)
  self.admin_params = {}
  return { render = "admin.registrations.new" }
end

function _M.create(self)
  local admin_params = _M.admin_params(self)
  local admin = assert(Admin:create(admin_params))
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

function _M.first_time_setup_check(self)
  if not Admin.needs_first_account() then
    self.flash["notice"] = _("An initial admin account already exists.")
    return self:write({ redirect_to = "/admin/" })
  end
end

return function(app)
  app:match("/admins/signup(.:format)", respond_to({
    before = function(self)
      _M.first_time_setup_check(self)
    end,
    GET = _M.new,
  }))
  app:match("/admins(.:format)", respond_to({
    before = function(self)
      _M.first_time_setup_check(self)
    end,
    POST = capture_errors({
      on_error = function(self)
        ngx.log(ngx.ERR, "ERRORS: " .. inspect(self.errors))
        return { render = "admin.registrations.new" }
      end,
      _M.create,
    }),
  }))
end
