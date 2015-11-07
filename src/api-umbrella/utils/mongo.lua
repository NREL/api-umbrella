local cjson = require "cjson"
local http = require "resty.http"

local _M = {}

local function try_query(path, http_options)
  if not http_options then
    http_options = {}
  end
  http_options["path"] = "/docs/api_umbrella/" .. config["mongodb"]["_database"] .. "/" .. path

  local httpc = http.new()
  httpc:set_timeout(45000)
  httpc:connect(config["mora"]["host"], config["mora"]["port"])

  local res, err = httpc:request(http_options)
  if err then
    err = "mongodb query failed: " .. err
    return nil, err
  end

  local body, body_err = res:read_body()
  if not body then
    return nil, body_err
  end

  local keepalive_ok, keepalive_err = httpc:set_keepalive()
  if not keepalive_ok then
    ngx.log(ngx.ERR, keepalive_err)
  end

  if not body or res.headers["Content-Type"] ~= "application/json" then
    err = "mongodb unexpected response format: " .. (body or nil)
    return nil, err
  end

  local response = cjson.decode(body)
  if not response["success"] then
    local mongodb_err = "mongodb error"
    if response["error"] and response["error"]["name"] then
      mongodb_err = mongodb_err .. ": " .. response["error"]["name"]
    end
    return nil, mongodb_err
  end

  return response
end

local function perform_query(path, query_options, http_options)
  if not query_options then
    query_options = {}
  end

  query_options["extended_json"] = "true"

  if type(query_options["query"]) == "table" then
    query_options["query"] = cjson.encode(query_options["query"])
  end

  if not http_options then
    http_options = {}
  end

  http_options["query"] = query_options

  local response, err = try_query(path, http_options)

  -- If we get an "EOF" error from Mora, this means our query occurred during
  -- the middle of a server or replicaset change. In this case, retry the
  -- request a couple more times.
  --
  -- This should be less likely in mora since
  -- https://github.com/emicklei/mora/pull/29, but it's still possible for this
  -- to crop up if the socket gets closed sometime between the request starting
  -- and the query actually executing. After more research, this seems to be
  -- expected mgo behavior, and it's up to the app to handle these type of
  -- errors. I'm not entirely sure whether we should try to address the issue
  -- in mora itself, but in the meantime, we'll retry here.
  if err and err == "mongodb error: EOF" then
    response, err = try_query(path, http_options)
    if err and err == "mongodb error: EOF" then
      ngx.sleep(0.5)
      response, err = try_query(path, http_options)
    end
  end

  if err then
    return nil, err
  else
    return response
  end
end

function _M.find(collection, query_options)
  local response, err = perform_query(collection, query_options)

  local results = {}
  if not err and response and response["data"] then
    results = response["data"]
  end

  -- If the error is simply no results (this seems to only be triggered on a
  -- query for the "_id" field), don't return an error, since we don't consider
  -- this an error, per-say, the results will just be empty.
  if err == "mongodb error: not found" then
    err = nil
  end

  return results, err
end

function _M.first(collection, query_options)
  if not query_options then
    query_options = {}
  end

  query_options["limit"] = 1

  local results, err = _M.find(collection, query_options)

  local result
  if not err and results then
    result = results[1]
  end

  return result, err
end

function _M.update(collection, id, data)
  local http_options = {
    method = "PUT",
    headers = {
      ["Content-Type"] = "application/json",
    },
    body = cjson.encode(data),
  }

  return perform_query(collection .. "/" .. id, nil, http_options)
end

function _M.create(collection, data)
  local http_options = {
    method = "POST",
    headers = {
      ["Content-Type"] = "application/json",
    },
    body = cjson.encode(data),
  }

  return perform_query(collection, nil, http_options)
end

return _M
