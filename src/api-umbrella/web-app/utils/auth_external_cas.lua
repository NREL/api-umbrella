local build_url = require "api-umbrella.utils.build_url"
local config = require("api-umbrella.utils.load_config")()
local http = require "resty.http"
local t = require("api-umbrella.web-app.utils.gettext").gettext
local xml = require "pl.xml"

local _M = {}

local function cas_url_root(options)
  local url
  if options["ssl"] then
    url = "https"
  else
    url = "http"
  end

  url = url .. "://" .. options["host"]
  return url
end

local function service_url(strategy_name)
  return build_url("/admins/auth/" .. strategy_name .. "/callback") .. "?" .. ngx.encode_args({
    url = build_url("/admin/"),
  })
end

local function parse_userinfo(body)
  -- Remove possible "cas:" XML namespace to simplify our simplistic parsing.
  local normalized_body, _, gsub_err = ngx.re.gsub(body, [[(</?)cas:]], "$1", "jo")
  if gsub_err then
    ngx.log(ngx.ERR, "regex error: ", gsub_err)
    return nil
  end

  local userinfo
  local data = xml.parse(normalized_body, false, true)
  if data then
    local success_element = data:child_with_name("authenticationSuccess")
    if success_element then
      userinfo = {}

      local user_element = success_element:child_with_name("user")
      if user_element then
        userinfo["user"] = user_element:get_text()
      end

      local attributes_element = success_element:child_with_name("attributes")
      if attributes_element then
        local max_security_level_element = attributes_element:child_with_name("maxAttribute:MaxSecurityLevel")
        if max_security_level_element then
          userinfo["max_security_level"] = max_security_level_element:get_text()
        end
      end
    else
      return nil, t("Authorization failed")
    end
  end

  return userinfo
end

function _M.authorize(strategy_name)
  local options = config["web"]["admin"]["auth_strategies"][strategy_name]["options"]

  local callback_url = service_url(strategy_name)
  local params = {
    service = callback_url,
  }
  if config["web"]["admin"]["auth_strategies"]["max.gov"]["require_mfa"] then
    params["securityLevel"] = "securePlus2"
  end
  local redirect = cas_url_root(options) .. options["login_url"] .. "?" .. ngx.encode_args(params)

  if config["app_env"] == "test" and ngx.var.cookie_test_mock_userinfo then
    redirect = callback_url
  end

  return { redirect_to = redirect }
end

function _M.userinfo(self, strategy_name)
  local options = config["web"]["admin"]["auth_strategies"][strategy_name]["options"]

  if config["app_env"] == "test" and ngx.var.cookie_test_mock_userinfo then
    local mock_userinfo = require "api-umbrella.web-app.utils.test_env_mock_userinfo"
    return parse_userinfo(mock_userinfo())
  end

  local httpc = http.new()

  if config["http_proxy"] or config["https_proxy"] then
    httpc:set_proxy_options({
      http_proxy = config["http_proxy"],
      https_proxy = config["https_proxy"],
    })
  end

  local res, err = httpc:request_uri(cas_url_root(options) .. options["service_validate_url"], {
    query = {
      service = service_url(strategy_name),
      ticket = assert(self.params["ticket"]),
    },
  })
  if err then
    ngx.log(ngx.ERR, "CAS service validate error: ", err)
    return nil, t("Authorization failed")
  elseif res.status >= 500 then
    ngx.log(ngx.ERR, "CAS service validate error response (" .. res.status .. "): " .. (res.body or ""))
    return nil, t("Authorization failed")
  elseif res.status >= 400 then
    ngx.log(ngx.WARN, "CAS service validate denied response (" .. res.status .. "): " .. (res.body or ""))
    return nil, t("Authorization denied")
  end

  return parse_userinfo(res.body)
end

return _M
