local build_url = require "api-umbrella.utils.build_url"
local deep_merge_overwrite_arrays = require "api-umbrella.utils.deep_merge_overwrite_arrays"
local http = require "resty.http"
local json_decode = require("cjson").decode
local random_token = require "api-umbrella.utils.random_token"

local _M = {}

local function redirect_uri(strategy_name)
  local url_name = strategy_name
  if strategy_name == "google" then
    url_name = "google_oauth2"
  end

  return build_url("/admins/auth/" .. url_name .. "/callback")
end

function _M.authorize(self, strategy_name, url, params)
  local state = random_token(64)
  self:init_session_client()
  self.resty_session_client:start()
  self.resty_session_client.data["oauth2_state"] = state
  self.resty_session_client:save()

  return {
    redirect_to = url .. "?" .. ngx.encode_args(deep_merge_overwrite_arrays({
      client_id = config["web"]["admin"]["auth_strategies"][strategy_name]["client_id"],
      response_type = "code",
      scope = "read_user",
      redirect_uri = redirect_uri(strategy_name),
      state = state,
    }, params)),
  }
end

function _M.userinfo(self, strategy_name, options)
  self:init_session_client()
  self.resty_session_client:open()
  if not self.resty_session_client or not self.resty_session_client.data or not self.resty_session_client.data["oauth2_state"] then
    ngx.log(ngx.ERR, "oauth2 state not available")
    return nil
  end

  local stored_state = self.resty_session_client.data["oauth2_state"]
  local state = self.params["state"]
  if state ~= stored_state then
    ngx.log(ngx.ERR, "oauth2 state does not match")
    return nil
  end

  local code = self.params["code"]

  local httpc = http.new()
  local res, err = httpc:request_uri(assert(options["token_endpoint"]), {
    method = "POST",
    headers = {
      ["Accept"] = "application/json",
      ["Content-Type"] = "application/x-www-form-urlencoded",
    },
    body = ngx.encode_args({
      code = code,
      client_id = config["web"]["admin"]["auth_strategies"][strategy_name]["client_id"],
      client_secret = config["web"]["admin"]["auth_strategies"][strategy_name]["client_secret"],
      redirect_uri = redirect_uri(strategy_name),
      grant_type = "authorization_code",
    }),
    query = options["token_query_params"],
  })
  if err then
    ngx.log(ngx.ERR, "oauth2 token error: ", err)
    return nil
  elseif res.status >= 400 then
    ngx.log(ngx.ERR, "oauth2 token unsuccessful response (" .. res.status .. "): " .. (res.body or ""))
    return nil
  end

  local data = json_decode(res.body)
  local token = assert(data["access_token"])

  res, err = httpc:request_uri(assert(options["userinfo_endpoint"]), {
    headers = {
      ["Accept"] = "application/json",
      ["Authorization"] = "Bearer " .. token,
    },
    query = options["userinfo_query_params"],
  })
  if err then
    ngx.log(ngx.ERR, "oauth2 userinfo error: ", err)
    return nil
  elseif res.status >= 400 then
    ngx.log(ngx.ERR, "oauth2 userinfo unsuccessful response (" .. res.status .. "): " .. (res.body or ""))
    return nil
  end

  return json_decode(res.body)
end

return _M
