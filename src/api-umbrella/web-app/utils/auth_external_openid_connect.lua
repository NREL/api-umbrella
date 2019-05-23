local build_url = require "api-umbrella.utils.build_url"
local config = require "api-umbrella.proxy.models.file_config"
local deep_merge_overwrite_arrays = require "api-umbrella.utils.deep_merge_overwrite_arrays"
local json_decode = require("cjson").decode
local openidc = require "resty.openidc"

if config["app_env"] == "development" or config["app_env"] == "test" then
  openidc.set_logging(nil, { DEBUG = ngx.NOTICE })
end

local _M = {}

function _M.authenticate(self, strategy_name, callback_path, options)
  if config["app_env"] == "test" and ngx.var.cookie_test_mock_userinfo then
    if ngx.var.uri == callback_path then
      local mock_userinfo = require "api-umbrella.web-app.utils.test_env_mock_userinfo"
      return json_decode(mock_userinfo()), nil
    else
      return ngx.redirect(build_url(callback_path))
    end
  end

  local res, err = openidc.authenticate(deep_merge_overwrite_arrays(deep_merge_overwrite_arrays(config["web"]["admin"]["auth_strategies"][strategy_name], {
    redirect_uri = build_url(callback_path),
    session_contents = {
      id_token = true,
    },
  }), options or {}), nil, nil, self.session_cookie_options)

  return res, err
end

return _M
