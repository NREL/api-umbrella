local auth_external = require "api-umbrella.web-app.utils.auth_external"
local config = require "api-umbrella.proxy.models.file_config"

return function(app)
  if config["web"]["admin"]["auth_strategies"]["_enabled"]["cas"] then
    app:get("/admins/auth/cas(.:format)", auth_external["cas"].login)
    app:get("/admins/auth/cas/callback(.:format)", auth_external["cas"].callback)
  end
  if config["app_env"] == "development" then
    app:get("/admins/auth/developer(.:format)", auth_external["developer"].login)
    app:post("/admins/auth/developer/callback(.:format)", auth_external["developer"].callback)
  end
  if config["web"]["admin"]["auth_strategies"]["_enabled"]["facebook"] then
    app:get("/admins/auth/facebook(.:format)", auth_external["facebook"].login)
    app:get("/admins/auth/facebook/callback(.:format)", auth_external["facebook"].callback)
  end
  if config["web"]["admin"]["auth_strategies"]["_enabled"]["github"] then
    app:get("/admins/auth/github(.:format)", auth_external["github"].login)
    app:get("/admins/auth/github/callback(.:format)", auth_external["github"].callback)
  end
  if config["web"]["admin"]["auth_strategies"]["_enabled"]["gitlab"] then
    app:get("/admins/auth/gitlab(.:format)", auth_external["gitlab"].login)
    app:get("/admins/auth/gitlab/callback(.:format)", auth_external["gitlab"].login)
    app:get("/admins/auth/gitlab/post-logout(.:format)", auth_external["gitlab"].post_logout)
  end
  if config["web"]["admin"]["auth_strategies"]["_enabled"]["google"] then
    app:get("/admins/auth/google_oauth2(.:format)", auth_external["google"].login)
    app:get("/admins/auth/google_oauth2/callback(.:format)", auth_external["google"].login)
    app:get("/admins/auth/google_oauth2/post-logout(.:format)", auth_external["google"].post_logout)
  end
  if config["web"]["admin"]["auth_strategies"]["_enabled"]["ldap"] then
    app:get("/admins/auth/ldap(.:format)", auth_external["ldap"].login)
    app:post("/admins/auth/ldap/callback(.:format)", auth_external["ldap"].callback)
  end
  if config["web"]["admin"]["auth_strategies"]["_enabled"]["login.gov"] then
    app:get("/admins/auth/login.gov(.:format)", auth_external["login.gov"].login)
    app:get("/admins/auth/login.gov/callback(.:format)", auth_external["login.gov"].login)
    app:get("/admins/auth/login.gov/post-logout(.:format)", auth_external["login.gov"].post_logout)
  end
  if config["web"]["admin"]["auth_strategies"]["_enabled"]["max.gov"] then
    app:get("/admins/auth/max.gov(.:format)", auth_external["max.gov"].login)
    app:get("/admins/auth/max.gov/callback(.:format)", auth_external["max.gov"].callback)
  end
end
