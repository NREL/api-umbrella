local Admin = require "api-umbrella.web-app.models.admin"
local build_url = require "api-umbrella.utils.build_url"
local cas = require "api-umbrella.web-app.utils.auth_external_cas"
local config = require("api-umbrella.utils.load_config")()
local escape_html = require("lapis.html").escape
local flash = require "api-umbrella.web-app.utils.flash"
local is_empty = require "api-umbrella.utils.is_empty"
local ldap = require "api-umbrella.web-app.utils.auth_external_ldap"
local login_admin = require "api-umbrella.web-app.utils.login_admin"
local oauth2 = require "api-umbrella.web-app.utils.auth_external_oauth2"
local openid_connect = require "api-umbrella.web-app.utils.auth_external_openid_connect"
local t = require("api-umbrella.web-app.utils.gettext").gettext
local username_label = require "api-umbrella.web-app.utils.username_label"

local _M = {}

local function email_unverified_error(self)
  flash.session(self, "danger", string.format(t([[The email address '%s' is not verified. Please <a href="%s">contact us</a> for further assistance.]]), escape_html(self.username or ""), escape_html(config["contact_url"] or "")), { html_safe = true })
  return ngx.redirect(build_url("/admin/login"))
end

local function mfa_required_error(self)
  flash.session(self, "danger", string.format(t([[You must use multi-factor authentication to sign in. Please try again, or <a href="%s">contact us</a> for further assistance.]]), escape_html(config["contact_url"] or "")), { html_safe = true })
  return ngx.redirect(build_url("/admin/login"))
end

local function login(self, strategy_name, err)
  if err then
    flash.session(self, "danger", string.format(t([[Could not authenticate you because "%s".]]), err))
    return ngx.redirect(build_url("/admin/login"))
  end

  if is_empty(self.username) then
    flash.session(self, "danger", string.format(t([[Could not authenticate you because "%s".]]), t("Invalid credentials")))
    return ngx.redirect(build_url("/admin/login"))
  end

  local admin = Admin:find_for_login(self.username)
  if admin then
    return ngx.redirect(login_admin(self, admin, strategy_name))
  else
    flash.session(self, "danger", string.format(t([[The account for '%s' is not authorized to access the admin. Please <a href="%s">contact us</a> for further assistance.]]), escape_html(self.username or ""), escape_html(config["contact_url"] or "")), { html_safe = true })
    return ngx.redirect(build_url("/admin/login"))
  end
end

local function admin_params(self)
  local params = {}
  if self.params and type(self.params["admin"]) == "table" then
    local input = self.params["admin"]
    params = {
      username = input["username"],
      password = input["password"],
    }
  end

  return params
end

_M["cas"] = {
  login = function()
    return cas.authorize("cas")
  end,

  callback = function(self)
    local userinfo, err = cas.userinfo(self, "cas")
    if userinfo then
      self.username = userinfo["user"]
    end

    return login(self, "cas", err)
  end,
}

_M["developer"] = {
  login = function(self)
    if config["app_env"] ~= "development" then
      return self.app.handle_404(self)
    end

    self.admin_params = {}
    self.username_label = username_label()
    return { render = require("api-umbrella.web-app.views.admin.auth_external.developer_login") }
  end,

  callback = function(self)
    if config["app_env"] ~= "development" then
      return self.app.handle_404(self)
    end

    self.admin_params = admin_params(self)
    if self.admin_params then
      local username = self.admin_params["username"]
      if not is_empty(username) then
        local admin = Admin:find({ username = username })
        if admin and not admin:is_access_locked() then
          self.username = username
        else
          self.current_admin = {
            id = "00000000-0000-0000-0000-000000000000",
            username = "admin",
            superuser = true,
          }
          ngx.ctx.current_admin = self.current_admin

          self.admin_params["superuser"] = true
          assert(Admin:create(self.admin_params))
          self.username = username
        end
      end
    end

    if self.username then
      return login(self, "developer")
    else
      self.username_label = username_label()
      return { render = require("api-umbrella.web-app.views.admin.auth_external.developer_login") }
    end
  end,
}

_M["facebook"] = {
  login = function(self)
    return oauth2.authorize(self, "facebook", "https://www.facebook.com/v2.11/dialog/oauth", {
      scope = "email",
    })
  end,

  callback = function(self)
    local userinfo, err = oauth2.userinfo(self, "facebook", {
      token_endpoint = "https://graph.facebook.com/v2.11/oauth/access_token",
      userinfo_endpoint = "https://graph.facebook.com/v2.11/me",
      userinfo_query_params = {
        fields = "email,verified",
      },
    })

    if userinfo then
      self.username = userinfo["email"]
      if not userinfo["verified"] then
        return email_unverified_error(self)
      end
    end

    return login(self, "facebook", err)
  end,
}

_M["github"] = {
  login = function(self)
    return oauth2.authorize(self, "github", "https://github.com/login/oauth/authorize", {
      scope = "user:email",
    })
  end,

  callback = function(self)
    local userinfo, err = oauth2.userinfo(self, "github", {
      token_endpoint = "https://github.com/login/oauth/access_token",
      userinfo_endpoint = "https://api.github.com/user/emails",
    })

    if userinfo then
      for _, email in ipairs(userinfo) do
        if email["primary"] then
          self.username = email["email"]

          if not email["verified"] then
            return email_unverified_error(self)
          end

          break
        end
      end
    end

    return login(self, "github", err)
  end,
}

_M["gitlab"] = {
  login = function(self)
    openid_connect.authenticate(self, "gitlab", function(res, err)
      if not err and res and res["user"] then
        self.username = res["user"]["email"]
        if not res["user"]["email_verified"] then
          return email_unverified_error(self)
        end
      end

      return login(self, "gitlab", err)
    end)
  end,

  logout = function(self)
    openid_connect.authenticate(self, "gitlab")
  end,
}

_M["google"] = {
  login = function(self)
    openid_connect.authenticate(self, "google", function(res, err)
      if not err and res and res["id_token"] then
        self.username = res["id_token"]["email"]
        if not res["id_token"]["email_verified"] then
          return email_unverified_error(self)
        end
      end

      return login(self, "google", err)
    end)
  end,

  logout = function(self)
    openid_connect.authenticate(self, "google")
  end,
}

_M["login.gov"] = {
  login = function(self)
    openid_connect.authenticate(self, "login.gov", function(res, err)
      if not err and res and res["id_token"] then
        self.username = res["id_token"]["email"]
        if not res["id_token"]["email_verified"] then
          return email_unverified_error(self)
        end
      end

      return login(self, "login.gov", err)
    end)
  end,

  logout = function(self)
    openid_connect.authenticate(self, "login.gov")
  end,
}

_M["ldap"] = {
  login = function(self)
    self.config = config
    self.username_label = username_label()
    if not self.admin_params then
      self.admin_params = {}
    end

    if config["app_env"] == "test" and ngx.var.cookie_test_mock_userinfo then
      return _M["ldap"].callback(self)
    end

    return { render = require("api-umbrella.web-app.views.admin.auth_external.ldap_login") }
  end,

  callback = function(self)
    self.admin_params = admin_params(self)
    local options = config["web"]["admin"]["auth_strategies"]["ldap"]["options"]
    local userinfo = ldap.userinfo(self.admin_params, options)

    if userinfo then
      self.username = userinfo[options["uid"]]
    end
    if self.username then
      return login(self, "ldap")
    else
      self.username_label = username_label()
      flash.now(self, "danger", string.format(t([[Could not authenticate you because "%s".]]), t("Invalid credentials")))
      return _M["ldap"].login(self)
    end
  end,
}

_M["max.gov"] = {
  login = function()
    return cas.authorize("max.gov")
  end,

  callback = function(self)
    local userinfo, err = cas.userinfo(self, "max.gov")
    if userinfo then
      self.username = userinfo["user"]
    end

    if config["web"]["admin"]["auth_strategies"]["max.gov"]["require_mfa"] then
      if not userinfo or not userinfo["max_security_level"] or not string.find(userinfo["max_security_level"], "securePlus2") then
        return mfa_required_error(self)
      end
    end

    return login(self, "max.gov", err)
  end,
}

return _M
