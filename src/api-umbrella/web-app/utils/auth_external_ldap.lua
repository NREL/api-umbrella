local config = require("api-umbrella.utils.load_config")()
local is_empty = require "api-umbrella.utils.is_empty"
local json_decode = require("cjson").decode
local lualdap = require "lualdap"

local _M = {}

function _M.userinfo(admin_params, options)
  if config["app_env"] == "test" and ngx.var.cookie_test_mock_userinfo then
    local mock_userinfo = require "api-umbrella.web-app.utils.test_env_mock_userinfo"
    return json_decode(mock_userinfo())
  end

  if type(admin_params) ~= "table" or is_empty(admin_params["username"]) or is_empty(admin_params["password"]) then
    return nil
  end

  local host = options["host"]
  if options["port"] then
    host = host .. ":" .. options["port"]
  end

  local usetls = false
  if options["method"] == "tls" then
    usetls = true
  end

  local userinfo
  local ldap, err = lualdap.open_simple(host, options["bind_dn"] or "", options["password"] or "", usetls)
  if not ldap then
    ngx.log(ngx.ERR, "LDAP connection error: ", err)
  else
    local user_dn
    local user_entry
    local filter = "(" .. options["uid"] .. "=" .. admin_params["username"] .. ")"
    for dn, entry in ldap:search({
      base = options["base"],
      scope = "subtree",
      filter = filter,
    }) do
      if dn then
        user_dn = dn
        user_entry = entry
        break
      end
    end
    ldap:close()

    if user_dn then
      local user_ldap, user_err = lualdap.open_simple(host, user_dn, admin_params["password"] or "", usetls)
      if user_ldap then
        userinfo = user_entry
        user_ldap:close()
      else
        ngx.log(ngx.ERR, "LDAP user connection error: ", user_err)
      end
    end
  end

  return userinfo
end

return _M
