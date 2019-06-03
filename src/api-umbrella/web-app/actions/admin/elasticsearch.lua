local capture_errors_json = require("api-umbrella.web-app.utils.capture_errors").json
local config = require "api-umbrella.proxy.models.file_config"
local elasticsearch_proxy_policy = require "api-umbrella.web-app.policies.elasticsearch_proxy_policy"
local http = require "resty.http"
local respond_to = require "api-umbrella.web-app.utils.respond_to"

local _M = {}

local prefix = "/admin/elasticsearch"

function _M.elasticsearch(self)
  elasticsearch_proxy_policy.authorize(self.current_admin)

  -- Proxy to the elasticsearch server.
  local httpc = http.new()
  local ok, err = httpc:connect(config["elasticsearch"]["_first_server"]["host"], config["elasticsearch"]["_first_server"]["port"])
  if not ok then
    ngx.log(ngx.ERR, err)
    return
  end

  -- Rewrite the URL to remove the admin prefix.
  local uri = ngx.re.gsub(ngx.var.uri, "^" .. prefix, "", "ijo")
  if #uri == 0 then
    uri = "/"
  end
  ngx.req.set_uri(uri)

  local response = httpc:proxy_request()

  -- Rewrite redirects
  if response.status >= 300 and response.status < 400 then
    -- Rewrite Location header redirects
    local location = response.headers["Location"]
    if location then
      -- Replace all URLs beginning with "/" that don't already begin with the
      -- prefix.
      local new_location, _, gsub_err = ngx.re.gsub(location, "^((?!" .. prefix .. ")/.*)$", prefix .. "$1", "ijo")
      if gsub_err then
        ngx.log(ngx.ERR, "regex error: ", gsub_err)
      else
        response.headers["Location"] = new_location
      end
    end

    -- Rewrite <meta> tag redirects.
    if response.has_body then
      local body = response:read_body()
      -- Replace all HTML tags in the format of url=* where the url begins with
      -- "/" but doesn't already begin with the prefix.
      local new_body, _, gsub_err = ngx.re.gsub(body, "(url=['\"]?)((?!" .. prefix .. ")/[^'\">]*)", "$1" .. prefix .. "$2", "ijo")
      if gsub_err then
        ngx.log(ngx.ERR, "regex error: ", gsub_err)
      else
        response.body_reader = coroutine.wrap(function()
          coroutine.yield(new_body)
          coroutine.yield(nil)
        end)
      end
    end
  end

  httpc:proxy_response(response)
  httpc:set_keepalive()

  return self:write({ layout = false })
end

return function(app)
  app:match(prefix .. "(*)", respond_to({ GET = capture_errors_json(_M.elasticsearch) }))
end
