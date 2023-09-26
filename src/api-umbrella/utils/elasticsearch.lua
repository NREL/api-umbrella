local config = require("api-umbrella.utils.load_config")()
local http = require "resty.http"
local icu_date = require "icu-date-ffi"
local is_empty = require "api-umbrella.utils.is_empty"
local json_decode = require("cjson").decode
local json_encode = require "api-umbrella.utils.json_encode"

local encode_base64 = ngx.encode_base64
local server = config["elasticsearch"]["_first_server"]

local _M = {}

if config["elasticsearch"]["index_partition"] == "monthly" then
  _M.partition_date_format = icu_date.formats.pattern("yyyy-MM")
elseif config["elasticsearch"]["index_partition"] == "daily" then
  _M.partition_date_format = icu_date.formats.pattern("yyyy-MM-dd")
else
  error("Unknown elasticsearch.index_partition configuration value")
end

function _M.query(path, options)
  local httpc = http.new()

  if config["http_proxy"] or config["https_proxy"] then
    httpc:set_proxy_options({
      http_proxy = config["http_proxy"],
      https_proxy = config["https_proxy"],
    })
  end

  if not options then
    options = {}
  end

  if options["server"] then
    server = options["server"]
    options["server"] = nil
  end

  options["path"] = path

  if not options["headers"] then
    options["headers"] = {}
  end

  if (server["user"] or server["password"]) and not options["headers"]["Authorization"] then
     options["headers"]["Authorization"] = "Basic " .. encode_base64((server["user"] or "") .. ":" .. (server["password"] or ""))
  end

  if options["body"] and type(options["body"]) == "table" then
    options["body"] = json_encode(options["body"])

    if not options["headers"]["Content-Type"] then
      options["headers"]["Content-Type"] = "application/json"
    end
  end

  local connect_ok, connect_err = httpc:connect({
    scheme = "http",
    host = server["host"],
    port = server["port"],
  })
  if not connect_ok then
    httpc:close()
    return nil, "elasticsearch connect error: " .. (connect_err or "")
  end

  if server["scheme"] == "https" then
    local ssl_ok, ssl_err = httpc:ssl_handshake(nil, server["host"], true)
    if not ssl_ok then
      httpc:close()
      return nil, "elasticsearch ssl handshake error: " .. (ssl_err or "")
    end
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
  res["body"] = body

  local keepalive_ok, keepalive_err = httpc:set_keepalive()
  if not keepalive_ok then
    httpc:close()
    return nil, "elasticsearch keepalive error: " .. (keepalive_err or "")
  end

  if res.status >= 300 and res.status ~= 404 then
    return nil, "Unsuccessful response: " .. (body or "")
  else
    if res.headers["Content-Type"] and string.sub(res.headers["Content-Type"], 1, 16) == "application/json" and not is_empty(body) then
      res["body_json"] = json_decode(body)

      if res["body_json"]["_shards"] and not is_empty(res["body_json"]["_shards"]["failures"]) then
        return nil, "Unsuccessful response: " .. (body or "")
      end
    end

    return res
  end
end

return _M
