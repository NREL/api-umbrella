local http = require "resty.http"
local json_decode = require("cjson").decode
local json_encode = require "api-umbrella.utils.json_encode"

local server = config["elasticsearch"]["_first_server"]

local _M = {}

function _M.query(path, options)
  local httpc = http.new()

  if not options then
    options = {}
  end

  options["path"] = path

  if not options["headers"] then
    options["headers"] = {}
  end

  if server["userinfo"] and not options["headers"]["Authorization"] then
     options["headers"]["Authorization"] = "Basic " .. ngx.encode_base64(server["userinfo"])
  end

  if options and options["body"] and type(options["body"]) == "table" then
    options["body"] = json_encode(options["body"])

    if not options["headers"]["Content-Type"] then
      options["headers"]["Content-Type"] = "application/json"
    end
  end

  httpc:connect(server["host"], server["port"])
  local res, err = httpc:request(options)
  if err then
    return nil, err
  end

  local body, body_err = res:read_body()
  if body_err then
    return nil, body_err
  end

  local keepalive_ok, keepalive_err = httpc:set_keepalive()
  if not keepalive_ok then
    ngx.log(ngx.ERR, keepalive_err)
  end

  if res.status >= 500 then
    return nil, "Unsuccessful response: " .. (body or "")
  else
    if res.headers["Content-Type"] and string.sub(res.headers["Content-Type"], 1, 16) == "application/json" then
      res["body_json"] = json_decode(body)
    end

    return res
  end
end

return _M
