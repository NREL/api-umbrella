local auth_external = require "api-umbrella.web-app.utils.auth_external"
local config = require("api-umbrella.utils.load_config")()
local csrf = require "api-umbrella.web-app.utils.csrf"
local respond_to = require "api-umbrella.web-app.utils.respond_to"

return function(app)
  if config["web"]["admin"]["auth_strategies"]["_enabled"]["cas"] then
    app:match("/admins/auth/cas(.:format)", respond_to({ POST = csrf.validate_token_filter(auth_external["cas"].login) }))
    app:match("/admins/auth/cas/callback(.:format)", respond_to({ GET = auth_external["cas"].callback }))
  end
  if config["app_env"] == "development" then
    app:match("/admins/auth/developer(.:format)", respond_to({ POST = csrf.validate_token_filter(auth_external["developer"].login) }))
    app:match("/admins/auth/developer/callback(.:format)", respond_to({ POST = csrf.validate_token_filter(auth_external["developer"].callback) }))
  end
  if config["web"]["admin"]["auth_strategies"]["_enabled"]["facebook"] then
    app:match("/admins/auth/facebook(.:format)", respond_to({ POST = csrf.validate_token_filter(auth_external["facebook"].login) }))
    app:match("/admins/auth/facebook/callback(.:format)", respond_to({ GET = auth_external["facebook"].callback }))
  end
  if config["web"]["admin"]["auth_strategies"]["_enabled"]["github"] then
    app:match("/admins/auth/github(.:format)", respond_to({ POST = csrf.validate_token_filter(auth_external["github"].login) }))
    app:match("/admins/auth/github/callback(.:format)", respond_to({ GET = auth_external["github"].callback }))
  end
  if config["web"]["admin"]["auth_strategies"]["_enabled"]["gitlab"] then
    app:match("/admins/auth/gitlab(.:format)", respond_to({ POST = csrf.validate_token_filter(auth_external["gitlab"].login) }))
    app:match("/admins/auth/gitlab/callback(.:format)", respond_to({ GET = auth_external["gitlab"].login }))
    app:match("/admins/auth/gitlab/post-logout(.:format)", respond_to({ GET = auth_external["gitlab"].post_logout }))
  end
  if config["web"]["admin"]["auth_strategies"]["_enabled"]["google"] then
    app:match("/admins/auth/google_oauth2(.:format)", respond_to({ POST = csrf.validate_token_filter(auth_external["google"].login) }))
    app:match("/admins/auth/google_oauth2/callback(.:format)", respond_to({ GET = auth_external["google"].login }))
    app:match("/admins/auth/google_oauth2/post-logout(.:format)", respond_to({ GET = auth_external["google"].post_logout }))
  end
  if config["web"]["admin"]["auth_strategies"]["_enabled"]["ldap"] then
    app:match("/admins/auth/ldap(.:format)", respond_to({ POST = csrf.validate_token_filter(auth_external["ldap"].login) }))
    app:match("/admins/auth/ldap/callback(.:format)", respond_to({ POST = csrf.validate_token_filter(auth_external["ldap"].callback) }))
  end
  if config["web"]["admin"]["auth_strategies"]["_enabled"]["login.gov"] then
    app:match("/admins/auth/login.gov(.:format)", respond_to({ POST = csrf.validate_token_filter(auth_external["login.gov"].login) }))
    app:match("/admins/auth/login.gov/callback(.:format)", respond_to({ GET = auth_external["login.gov"].login }))
    app:match("/admins/auth/login.gov/post-logout(.:format)", respond_to({ GET = auth_external["login.gov"].post_logout }))
  end
  if config["web"]["admin"]["auth_strategies"]["_enabled"]["max.gov"] then
    app:match("/admins/auth/max.gov(.:format)", respond_to({ POST = csrf.validate_token_filter(auth_external["max.gov"].login) }))
    app:match("/admins/auth/max.gov/callback(.:format)", respond_to({ GET = auth_external["max.gov"].callback }))
  end
end
