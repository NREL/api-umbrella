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

  local connect_ok, connect_err = httpc:connect(server["host"], server["port"])
  if connect_err then
    httpc:close()
    return nil, "elasticsearch connect error: " .. (connect_err or "")
  end

  local res, err = httpc:request(options)
  if err then
    httpc:close()
    return nil, "elasticsearch request error: " .. (err or "")
  end

  local body, body_err = res:read_body()
  if body_err then
    httpc:close()
    return nil, "elasticsearch read body error: " .. (body_err or "")
  end

  local keepalive_ok, keepalive_err = httpc:set_keepalive()
  if not keepalive_ok then
    httpc:close()
    return nil, "elasticsearch keepalive error: " .. (keepalive_err or "")
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
