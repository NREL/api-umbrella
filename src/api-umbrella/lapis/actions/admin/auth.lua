local Admin = require "api-umbrella.lapis.models.admin"
local ApiUser = require "api-umbrella.lapis.models.api_user"
local array_includes = require "api-umbrella.utils.array_includes"
local lapis_json = require "api-umbrella.utils.lapis_json"

local _M = {}

function _M.auth(self)
  local response = {
    authenticated = false,
  }

  local current_admin = Admin:select("LIMIT 1")[1]
  if current_admin then
    local admin = current_admin:as_json()
    local api_user = ApiUser:select("WHERE email = ? ORDER BY created_at LIMIT 1", "web.admin.ajax@internal.apiumbrella")[1]

    response["authenticated"] = true
    response["analytics_timezone"] = config["analytics"]["timezone"]
    response["enable_beta_analytics"] = (config["analytics"]["adapter"] == "kylin" or (config["analytics"]["outputs"] and array_includes(config["analytics"]["outputs"], "kylin")))
    response["username_is_email"] = config["web"]["admin"]["username_is_email"]
    response["local_auth_enabled"] = config["web"]["admin"]["auth_strategies"]["_local_enabled?"]
    response["password_length_min"] = config["web"]["admin"]["password_length_min"]
    -- response["api_umbrella_version"] = API_UMBRELLA_VERSION
    response["admin"] = {}
    response["admin"]["email"] = admin["email"]
    response["admin"]["id"] = admin["id"]
    response["admin"]["superuser"] = admin["superuser"]
    response["admin"]["username"] = admin["username"]
    response["api_key"] = api_user.api_key
    response["admin_auth_token"] = current_admin.authentication_token
  end

  ngx.log(ngx.ERR, "RESPONSE: " .. inspect(response))

  return lapis_json(self, response)
end

return function(app)
  app:get("/admin/auth(.:format)", _M.auth)
end
