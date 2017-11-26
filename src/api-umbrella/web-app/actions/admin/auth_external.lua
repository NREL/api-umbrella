local Admin = require "api-umbrella.web-app.models.admin"
local build_url = require "api-umbrella.utils.build_url"
local is_empty = require("pl.types").is_empty
local username_label = require "api-umbrella.web-app.utils.username_label"

local _M = {}

function _M.cas_login(self)
  return { redirect_to = "/" }
end

function _M.cas_callback(self)
  return { redirect_to = "/" }
end

function _M.developer_login(self)
  if config["app_env"] ~= "development" then
    return self.app.handle_404(self)
  end

  self.admin_params = {}
  self.username_label = username_label()
  return { render = "admin.auth_external.developer_login" }
end

function _M.developer_callback(self)
  if config["app_env"] ~= "development" then
    return self.app.handle_404(self)
  end

  local admin_id
  local admin_params = _M.admin_params(self)
  if admin_params then
    local username = admin_params["username"]
    if not is_empty(username) then
      local admin = Admin:find({ username = username })
      if admin and not admin:is_access_locked() then
        admin_id = admin.id
      else
        self.current_admin = {
          id = "00000000-0000-0000-0000-000000000000",
          username = "admin",
          superuser = true,
        }
        ngx.ctx.current_admin = self.current_admin

        admin_params["superuser"] = true
        admin = assert(Admin:create(admin_params))
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
    self.username_label = username_label()
    return { render = "admin.auth_external.developer_login" }
  end
end

function _M.facebook_login(self)
  return { redirect_to = "/" }
end

function _M.facebook_callback(self)
  return { redirect_to = "/" }
end

function _M.github_login(self)
  return { redirect_to = "/" }
end

function _M.github_callback(self)
  return { redirect_to = "/" }
end

function _M.gitlab_login(self)
  return { redirect_to = "/" }
end

function _M.gitlab_callback(self)
  return { redirect_to = "/" }
end

function _M.google_login(self)
  return {
    redirect_to = "https://accounts.google.com/o/oauth2/auth?" .. ngx.encode_args({
      access_type = "offline",
      client_id = "test",
      prompt = "select_account",
      redirect_uri = build_url("/admins/auth/google_oauth2/callback"),
      response_type = "code",
      scope = "https://www.googleapis.com/auth/email",
      state = "test",
    }),
  }
end

function _M.google_callback(self)
  return { redirect_to = "/" }
end

function _M.ldap_login(self)
  self.admin_params = {}
  self.username_label = username_label()
  return { render = "admin.auth_external.ldap_login" }
end

function _M.ldap_callback(self)
  return { redirect_to = "/" }
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

return function(app)
  app:get("/admins/auth/cas(.:format)", _M.cas_login)
  app:get("/admins/auth/cas/callback(.:format)", _M.cas_callback)
  app:get("/admins/auth/developer(.:format)", _M.developer_login)
  app:post("/admins/auth/developer/callback(.:format)", _M.developer_callback)
  app:get("/admins/auth/facebook(.:format)", _M.facebook_login)
  app:get("/admins/auth/facebook/callback(.:format)", _M.facebook_callback)
  app:get("/admins/auth/github(.:format)", _M.github_login)
  app:get("/admins/auth/github/callback(.:format)", _M.github_callback)
  app:get("/admins/auth/gitlab(.:format)", _M.gitlab_login)
  app:get("/admins/auth/gitlab/callback(.:format)", _M.gitlab_callback)
  app:get("/admins/auth/google_oauth2(.:format)", _M.google_login)
  app:get("/admins/auth/google_oauth2/callback(.:format)", _M.google_callback)
  app:get("/admins/auth/ldap(.:format)", _M.ldap_login)
  app:post("/admins/auth/ldap/callback(.:format)", _M.ldap_callback)
end
