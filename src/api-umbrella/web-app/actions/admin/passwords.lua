local Admin = require "api-umbrella.web-app.models.admin"
local admin_reset_password_mailer = require "api-umbrella.web-app.mailers.admin_reset_password"
local build_url = require "api-umbrella.utils.build_url"
local capture_errors = require("lapis.application").capture_errors
local csrf = require "api-umbrella.web-app.utils.csrf"
local db_null = require("lapis.db").NULL
local flash = require "api-umbrella.web-app.utils.flash"
local is_empty = require("pl.types").is_empty
local t = require("api-umbrella.web-app.utils.gettext").gettext

local _M = {}

function _M.new()
  return { render = "admin.passwords.new" }
end

function _M.create(self)
  local admin
  local admin_params = _M.admin_params_create(self)
  if not is_empty(admin_params["email"]) then
    admin = Admin:find({ email = admin_params["email"] })
  end

  local message_level = "info"
  local message = t("If your email address exists in our database, you will receive a password recovery link at your email address in a few minutes.")
  if admin then
    local token = admin:set_reset_password_token()
    local ok, err = admin_reset_password_mailer(admin, token)
    if not ok then
      ngx.log(ngx.ERR, "mail error: ", err)
      message_level = "danger"
      message = t("An unexpected error occurred when sending the email.")
    end
  end

  flash.session(self, message_level, message)
  return self:write({ redirect_to = build_url("/admin/login") })
end

function _M.edit()
  return { render = "admin.passwords.edit" }
end

function _M.update(self)
  local admin = Admin:find_by_reset_password_token(self.params["reset_password_token"])
  if not admin then
    return coroutine.yield("error", { reset_password_token = { t("Reset password token is invalid") } })
  end

  if admin:is_reset_password_expired() then
    return coroutine.yield("error", { reset_password_token = { t("Reset password token has expired, please request a new one") } })
  end

  self.current_admin = {
    id = "00000000-0000-0000-0000-000000000000",
    username = "admin",
    superuser = true,
  }
  ngx.ctx.current_admin = self.current_admin

  local admin_params = _M.admin_params_update(self)
  admin_params["reset_password_token_hash"] = db_null
  admin_params["reset_password_sent_at"] = db_null
  admin._reset_password_mode = true
  admin:authorized_update(admin_params)

  self:init_session_db()
  self.session_db:start()
  self.session_db.data["admin_id"] = admin.id
  self.session_db:save()

  return { redirect_to = build_url("/admin/#/login") }
end

function _M.admin_params_create(self)
  local params = {}
  if self.params and self.params["admin"] then
    local input = self.params["admin"]
    params = {
      email = input["email"],
    }
  end

  return params
end

function _M.admin_params_update(self)
  local params = {}
  if self.params and self.params["admin"] then
    local input = self.params["admin"]
    params = {
      password = input["password"],
      password_confirmation = input["password_confirmation"],
    }
  end

  return params
end

return function(app)
  app:get("/admins/password/new(.:format)", _M.new)
  app:post("/admins/password(.:format)", csrf.validate_token_filter(capture_errors({
    on_error = function()
      return { render = "admin.passwords.new" }
    end,
    _M.create,
  })))
  app:get("/admins/password/edit(.:format)", _M.edit)
  app:post("/admins/password/update(.:format)", csrf.validate_token_filter(capture_errors({
    on_error = function()
      return { render = "admin.passwords.edit" }
    end,
    _M.update,
  })))
end
