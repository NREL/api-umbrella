local build_url = require "api-umbrella.utils.build_url"

local _M = {}

function _M.cas_login(self)
  return { redirect_to = "/" }
end

function _M.cas_callback(self)
  return { redirect_to = "/" }
end

function _M.developer_login(self)
  return { redirect_to = "/" }
end

function _M.developer_callback(self)
  return { redirect_to = "/" }
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
  return { redirect_to = "/" }
end

function _M.ldap_callback(self)
  return { redirect_to = "/" }
end

return function(app)
  app:get("/admins/auth/cas(.:format)", _M.cas_login)
  app:get("/admins/auth/cas/callback(.:format)", _M.cas_callback)
  app:get("/admins/auth/developer(.:format)", _M.developer_login)
  app:get("/admins/auth/developer/callback(.:format)", _M.developer_callback)
  app:get("/admins/auth/facebook(.:format)", _M.facebook_login)
  app:get("/admins/auth/facebook/callback(.:format)", _M.facebook_callback)
  app:get("/admins/auth/github(.:format)", _M.github_login)
  app:get("/admins/auth/github/callback(.:format)", _M.github_callback)
  app:get("/admins/auth/gitlab(.:format)", _M.gitlab_login)
  app:get("/admins/auth/gitlab/callback(.:format)", _M.gitlab_callback)
  app:get("/admins/auth/google_oauth2(.:format)", _M.google_login)
  app:get("/admins/auth/google_oauth2/callback(.:format)", _M.google_callback)
  app:get("/admins/auth/ldap(.:format)", _M.ldap_login)
  app:get("/admins/auth/ldap/callback(.:format)", _M.ldap_callback)
end
