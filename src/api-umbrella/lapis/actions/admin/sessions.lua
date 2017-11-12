local Admin = require "api-umbrella.lapis.models.admin"
local ApiUser = require "api-umbrella.lapis.models.api_user"
local array_includes = require "api-umbrella.utils.array_includes"
local build_url = require "api-umbrella.utils.build_url"
local csrf = require "lapis.csrf"
local flash = require "api-umbrella.utils.lapis_flash"
local is_empty = require("pl.types").is_empty
local json_null = require("cjson").null
local lapis_json = require "api-umbrella.utils.lapis_json"
local random_token = require "api-umbrella.utils.random_token"
local respond_to = require("lapis.application").respond_to
local t = require("resty.gettext").gettext

local _M = {}

function _M.new(self)
  self.cookies["_api_umbrella_csrf_token"] = random_token(40)
  self.csrf_token = csrf.generate_token(self, self.cookies["_api_umbrella_csrf_token"])

  self.admin_params = {}
  return { render = "admin.sessions.new" }
end

function _M.create(self)
  csrf.assert_token(self, self.cookies["_api_umbrella_csrf_token"])

  local admin_id
  local admin_params = _M.admin_params(self)
  if admin_params then
    local username = admin_params["username"]
    local password = admin_params["password"]
    if not is_empty(username) and not is_empty(password) then
      local admin = Admin:find({ username = username })
      if admin and not admin:is_access_locked() and admin:is_valid_password(password) then
        admin_id = admin.id
      end
    end
  end

  if admin_id then
    self:init_session()
    self.resty_session:start()
    self.resty_session.data["admin_id"] = admin_id
    self.resty_session:save()

    return { redirect_to = build_url("/admin/") }
  else
    self.admin_params = admin_params
    flash.now(self, "warning", t("Invalid email or password."))
    return { render = "admin.sessions.new" }
  end
end

function _M.destroy(self)
  self:init_session()
  self.resty_session:open()
  self.resty_session:destroy()
  return { status = 204 }
end

function _M.auth(self)
  local response = {
    authenticated = false,
  }

  local current_admin = self.current_admin
  if current_admin then
    local admin = current_admin:as_json()
    local api_user = ApiUser:select("WHERE email = ? ORDER BY created_at LIMIT 1", "web.admin.ajax@internal.apiumbrella")[1]

    response["authenticated"] = true
    response["analytics_timezone"] = config["analytics"]["timezone"] or json_null
    response["enable_beta_analytics"] = (config["analytics"]["adapter"] == "kylin" or (config["analytics"]["outputs"] and array_includes(config["analytics"]["outputs"], "kylin")))
    response["username_is_email"] = config["web"]["admin"]["username_is_email"] or json_null
    response["local_auth_enabled"] = config["web"]["admin"]["auth_strategies"]["_local_enabled?"] or json_null
    response["password_length_min"] = config["web"]["admin"]["password_length_min"] or json_null
    response["api_umbrella_version"] = API_UMBRELLA_VERSION or json_null
    response["admin"] = {}
    response["admin"]["email"] = admin["email"] or json_null
    response["admin"]["id"] = admin["id"] or json_null
    response["admin"]["superuser"] = admin["superuser"] or json_null
    response["admin"]["username"] = admin["username"] or json_null
    response["api_key"] = api_user:api_key_decrypted() or json_null
    response["admin_auth_token"] = current_admin:authentication_token_decrypted() or json_null
  end

  return lapis_json(self, response)
end

function _M.admin_params(self)
  local params = {}
  if self.params and self.params["admin"] then
    local input = self.params["admin"]
    params = {
      username = input["username"],
      password = input["password"],
    }
  end

  return params
end

function _M.first_time_setup_check(self)
  if Admin.needs_first_account() then
    return self:write({ redirect_to = build_url("/admins/signup") })
  end
end

return function(app)
  app:match("/admin/login(.:format)", respond_to({
    before = function(self)
      _M.first_time_setup_check(self)
      if self.current_admin then
        return self:write({ redirect_to = build_url("/admin/") })
      end
    end,
    GET = _M.new,
    POST = _M.create,
  }))
  app:delete("/admin/logout(.:format)", _M.destroy)
  app:get("/admin/auth(.:format)", _M.auth)
end
