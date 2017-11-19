local http = require "resty.http"
local json_decode = require("cjson").decode
local json_encode = require "api-umbrella.utils.json_encode"

local elasticsearch_host = config["elasticsearch"]["hosts"][1]

local _M = {}

function _M.query(path, options)
  local httpc = http.new()

  if options and options["body"] and type(options["body"]) == "table" then
    options["body"] = json_encode(options["body"])

    if not options["headers"] then
      options["headers"] = {}
    end
    if not options["headers"]["Content-Type"] then
      options["headers"]["Content-Type"] = "application/json"
    end
  end

  local res, err = httpc:request_uri(elasticsearch_host .. path, options)
  if err then
    return nil, err
  elseif res.status >= 500 then
    return nil, "Unsuccessful response: " .. (res.body or "")
  else
    if res.headers["Content-Type"] and string.sub(res.headers["Content-Type"], 1, 16) == "application/json" then
      res["body_json"] = json_decode(res.body)
    end

    return res
  end
end

return _M
