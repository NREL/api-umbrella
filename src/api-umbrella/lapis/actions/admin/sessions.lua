local Admin = require "api-umbrella.lapis.models.admin"
local _ = require("resty.gettext").gettext
local cjson = require "cjson"
local respond_to = require("lapis.application").respond_to
local ApiUser = require "api-umbrella.lapis.models.api_user"
local array_includes = require "api-umbrella.utils.array_includes"
local lapis_json = require "api-umbrella.utils.lapis_json"
local random_token = require "api-umbrella.utils.random_token"
local csrf = require "lapis.csrf"
local types = require "pl.types"

local is_empty = types.is_empty
local json_null = cjson.null

local _M = {}

local session = require("resty.session").new({
  -- storage = "shm",
  name = "_api_umbrella_session",
  secret = config["web"]["rails_secret_token"],
  random = {
    length = 30,
  },
})

local function set_current_admin(self)
  local current_admin

  session:open()
  if session and session.data and session.data["admin_id"] then
    local admin_id = session.data["admin_id"]
    local admin = Admin:find({ id = admin_id })
    if not admin:is_access_locked() then
      current_admin = admin
    end
  end

  self.current_admin = current_admin
end

function _M.new(self)
  self.cookies.csrf_token = random_token(40)
  self.csrf_token = csrf.generate_token(self, self.cookies.csrf_token)

  ngx.log(ngx.ERR, "SESSION COOKIE: " .. inspect(ngx.var.http_cookie))
  ngx.log(ngx.ERR, "SESSION DATA: " .. inspect(session.data))
  ngx.log(ngx.ERR, "SESSION DATA: " .. inspect(session.data.name))

  self.admin_params = {}
  return { render = "admin.sessions.new" }
end

function _M.create(self)
  csrf.assert_token(self, self.cookies.csrf_token)

  local admin_id
  local admin_params = _M.admin_params(self)
  if admin_params then
    local username = admin_params["username"]
    local password = admin_params["password"]
    if not is_empty(username) and not is_empty(password) then
      local admin = Admin:find({ username = username })
      if admin and admin:is_valid_password(password) then
        admin_id = admin.id
      end
    end
  end

  if admin_id then
    session:start()
    session.data["admin_id"] = admin_id
    session:save()

    return { redirect_to = "/admin/" }
  else
    self.admin_params = admin_params
    self.flash["warning"] = _("Invalid email or password.")
    return { render = "admin.sessions.new" }
  end
end

function _M.destroy()
  set_current_admin(self)
  if self.current_admin then
    session:destroy()
    return { status = 204 }
  end
end

function _M.auth(self)
  set_current_admin(self)

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
    response["api_key"] = api_user.api_key or json_null
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
    return self:write({ redirect_to = "/admins/signup" })
  end
end

return function(app)
  app:match("/admin/login(.:format)", respond_to({
    before = function(self)
      _M.first_time_setup_check(self)
      set_current_admin(self)
      if self.current_admin then
        ngx.log(ngx.ERR, "REDIRECT TO ADMIN")
        return self:write({ redirect_to = "/admin/" })
      end
    end,
    GET = _M.new,
    POST = _M.create,
  }))
  app:delete("/admin/logout(.:format)", _M.destroy)
  app:get("/admin/auth(.:format)", _M.auth)
end
