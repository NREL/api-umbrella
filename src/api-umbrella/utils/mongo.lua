local config = require "api-umbrella.proxy.models.file_config"
local http = require "resty.http"
local is_empty = require "api-umbrella.utils.is_empty"
local json_decode = require("cjson").decode
local json_encode = require "api-umbrella.utils.json_encode"
local stringx = require "pl.stringx"

local startswith = stringx.startswith

local _M = {}

local function try_query(path, http_options)
  if not http_options then
    http_options = {}
  end
  http_options["path"] = "/docs/api_umbrella/" .. config["mongodb"]["_database"] .. "/" .. path

  local httpc = http.new()
  httpc:set_timeout(45000)
  httpc:connect({
    scheme = "http",
    host = config["mora"]["host"],
    port = config["mora"]["port"],
  })

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

  local response = json_decode(body)
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
    query_options["query"] = json_encode(query_options["query"])
  end

  if not http_options then
    http_options = {}
  end

  http_options["query"] = query_options

  local response, err = try_query(path, http_options)

  -- If we encounter certain types of errors from Mora, this means our query
  -- occurred during the middle of a server or replicaset change. In this case,
  -- retry the request a few more times.
  --
  -- This should be less likely in mora since
  -- https://github.com/emicklei/mora/pull/29, but it's still possible for this
  -- to crop up if the socket gets closed sometime between the request starting
  -- and the query actually executing. This can also happen in case of
  -- unexpected mongod shutdowns. After more research, this seems to be
  -- expected mgo behavior, and it's up to the app to handle these type of
  -- errors. I'm not entirely sure whether we should try to address the issue
  -- in mora itself, but in the meantime, we'll retry here.
  if err then
    -- Loop to retry a few times until no errors occurs or we give up, since we
    -- don't want to wait forever.
    local retries = 0
    while err and retries < 5 do
      if err == "mongodb error: EOF"
        or err == "mongodb error: node is recovering"
        or err == "mongodb error: interrupted at shutdown"
        or err == "mongodb error: operation was interrupted"
        or err == "mongodb error: Closed explicitly"
        or startswith(err, "mongodb error: read tcp")
        or startswith(err, "mongodb error: write tcp")
        then
        -- Retry immediately, then sleep between further retries.
        retries = retries + 1
        if retries > 1 then
          ngx.sleep(0.5)
        end

        response, err = try_query(path, http_options)
      else
        break
      end
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

    -- Queries on the "_id" field only return a single result directly on the
    -- "data" attribute. For consistency sake, still wrap these single record
    -- query responses in an array (so both _id and other types of queries are
    -- compatible with the _M.first function).
    if results and not results[1] and not is_empty(results) then
      results = { results }
    end
  end

  -- If the error is simply no results (this seems to only be triggered on a
  -- query for the "_id" field), don't return an error, since we don't consider
  -- this an error, per-say, the results will just be empty.
  if err == "mongodb error: not found" then
    err = nil
  end

  return results, err
end

function _M.collections()
  local collection = ""
  local query_options = {}
  return _M.find(collection, query_options)
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
    body = json_encode(data),
  }

  return perform_query(collection .. "/" .. id, nil, http_options)
end

function _M.create(collection, data)
  local http_options = {
    method = "POST",
    headers = {
      ["Content-Type"] = "application/json",
    },
    body = json_encode(data),
  }

  return perform_query(collection, nil, http_options)
end

function _M.delete(collection, id)
  local http_options = {
    method = "DELETE",
    headers = {
      ["Content-Type"] = "application/json",
    },
  }

  return perform_query(collection .. "/" .. id, nil, http_options)
end

return _M
