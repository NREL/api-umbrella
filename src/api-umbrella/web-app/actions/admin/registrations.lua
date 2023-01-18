local Admin = require "api-umbrella.web-app.models.admin"
local build_url = require "api-umbrella.utils.build_url"
local capture_errors = require("lapis.application").capture_errors
local config = require("api-umbrella.utils.load_config")()
local csrf = require "api-umbrella.web-app.utils.csrf"
local flash = require "api-umbrella.web-app.utils.flash"
local login_admin = require "api-umbrella.web-app.utils.login_admin"
local respond_to = require "api-umbrella.web-app.utils.respond_to"
local t = require("api-umbrella.web-app.utils.gettext").gettext
local username_label = require "api-umbrella.web-app.utils.username_label"

local _M = {}

function _M.new(self)
  if not self.admin_params then
    self.admin_params = {}
  end

  self.config = config
  self.username_label = username_label()
  return { render = require("api-umbrella.web-app.views.admin.registrations.new") }
end

function _M.create(self)
  self.current_admin = {
    id = "00000000-0000-0000-0000-000000000000",
    username = "admin",
    superuser = true,
  }
  ngx.ctx.current_admin = self.current_admin

  self.admin_params = _M.admin_params(self)
  local admin = assert(Admin:create(self.admin_params))
  return { redirect_to = login_admin(self, admin, "local") }
end

function _M.admin_params(self)
  local params = {}
  if self.params and type(self.params["admin"]) == "table" then
    local input = self.params["admin"]
    params = {
      username = input["username"],
      password = input["password"],
      password_confirmation = input["password_confirmation"],

      -- Make the first admin a superuser on initial setup.
      superuser = true,
    }
  end

  return params
end

function _M.first_time_setup_check(self)
  if not Admin.needs_first_account() then
    flash.session(self, "info", t("An initial admin account already exists."))
    return self:write({ redirect_to = build_url("/admin/") })
  end
end

return function(app)
  if config["web"]["admin"]["auth_strategies"]["_enabled"]["local"] then
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
      POST = csrf.validate_token_filter(capture_errors({
        on_error = _M.new,
        _M.create,
      })),
    }))
  end
end
