local auth_external_path = require "api-umbrella.web-app.utils.auth_external_path"
local build_url = require "api-umbrella.utils.build_url"
local config = require "api-umbrella.proxy.models.file_config"
local deep_merge_overwrite_arrays = require "api-umbrella.utils.deep_merge_overwrite_arrays"
local deepcopy = require("pl.tablex").deepcopy
local json_decode = require("cjson").decode
local openidc = require "resty.openidc"
local random_token = require "api-umbrella.utils.random_token"

if config["app_env"] == "development" or config["app_env"] == "test" then
  openidc.set_logging(nil, { DEBUG = ngx.NOTICE })
end

local _M = {}

function _M.authenticate(self, strategy_name)
  local callback_path = auth_external_path(strategy_name, "/callback")

  local openidc_options = deepcopy(config["web"]["admin"]["auth_strategies"][strategy_name])
  deep_merge_overwrite_arrays(openidc_options, {
    redirect_uri = build_url(callback_path),
    revoke_tokens_on_logout = true,
    logout_path = "/admin/logout",
    post_logout_redirect_uri = build_url("/admin/logout/callback"),
    session_contents = {
      id_token = true,

      enc_id_token = true,
      access_token = true,
      refresh_token = true,
    },
  })

  -- GitLab's OpenID Connect provider doesn't supply the email in the id_token
  -- (https://gitlab.com/gitlab-org/gitlab-ee/issues/5365). So for this
  -- provider, we must also access the userinfo endpoint to fetch the email.
  if strategy_name == "gitlab" then
    openidc_options["session_contents"]["user"] = true
  end

  -- When handling a logout, lua-resty-openidc doesn't currently append the
  -- optional "state" param to the logout URL, which Login.gov requires. So
  -- work around this by manually adding it.
  if ngx.var.uri == openidc_options["logout_path"] then
    -- Fetch the discovery information and see if the "end_session_endpoint"
    -- item is set.
    local discovery, err = openidc.get_discovery_doc(openidc_options)
    if discovery and discovery["end_session_endpoint"] then
      -- Generate the state parameter to send.
      self:init_session_cookie()
      self.session_cookie:start()
      self.session_cookie.data["openid_connect_state"] = random_token(64)
      self.session_cookie:save()

      -- Add the "state" param to the logout URL.
      local logout_uri = discovery["end_session_endpoint"]
      local separator = "?"
      if string.find(logout_uri, "?", 1, true) then
        separator = "&"
      end
      logout_uri = logout_uri .. separator .. ngx.encode_args({ state = self.session_cookie.data["openid_connect_state"] })

      openidc_options["redirect_after_logout_uri"] = logout_uri

      -- This option needs to be explicitly enabled whenever
      -- "redirect_after_logout_uri" is manually set for compatibility with the
      -- default "end_session_endpoint" behavior.
      openidc_options["redirect_after_logout_with_id_token_hint"] = true
    elseif err then
      ngx.log(ngx.ERR, "Failed to fetch openidc discovery: ", err)
    end
  end

  -- Create a separate session for lua-resty-openidc's storage so it doesn't
  -- conflict with any of our sessions.
  local session_options = deepcopy(self.session_db_options)
  session_options["name"] = "_api_umbrella_openidc"

  -- In the test environment allow mocking the login process.
  if config["app_env"] == "test" and ngx.var.cookie_test_mock_userinfo then
    if ngx.var.uri == callback_path then
      local mock_userinfo = require "api-umbrella.web-app.utils.test_env_mock_userinfo"
      return json_decode(mock_userinfo()), nil
    elseif ngx.var.uri == openidc_options["logout_path"] then
      return ngx.redirect(openidc_options["post_logout_redirect_uri"])
    else
      return ngx.redirect(openidc_options["redirect_uri"])
    end
  end

  local res, err = openidc.authenticate(openidc_options, nil, nil, session_options)
  if err then
    ngx.log(ngx.WARN, "OpenID Connect error: ", err)
  end

  return res, err
end

return _M
