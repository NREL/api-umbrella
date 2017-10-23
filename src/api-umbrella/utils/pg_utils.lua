local int64 = require "api-umbrella.utils.int64"
local pgmoon = require "pgmoon"

local _escape_literal = pgmoon.Postgres.escape_literal
local _escape_identifier = pgmoon.Postgres.escape_identifier
local pg_null = pgmoon.Postgres.NULL

local db_config = {
  host = config["postgresql"]["host"],
  port = config["postgresql"]["port"],
  database = config["postgresql"]["database"],
  user = config["postgresql"]["username"],
  password = config["postgresql"]["password"],
}

local _M = {}

local LIST_METATABLE = {}

local function encode_values(values)
  local escaped_columns = {}
  local escaped_values = {}
  for column, value in pairs(values) do
    table.insert(escaped_columns, _M.escape_identifier(column))
    table.insert(escaped_values, _M.escape_literal(value))
  end

  return "(" .. table.concat(escaped_columns, ", ") .. ") VALUES (" .. table.concat(escaped_values, ", ") .. ")"
end

local function encode_assigns(values)
  local escaped_assigns = {}
  for column, value in pairs(values) do
    table.insert(escaped_assigns, _M.escape_identifier(column) .. " = " .. _M.escape_literal(value))
  end

  return table.concat(escaped_assigns, ", ")
end

function _M.list(value)
  return setmetatable({ value }, LIST_METATABLE)
end

function _M.is_list(value)
  return getmetatable(value) == LIST_METATABLE
end

function _M.escape_literal(value)
  if value == nil or value == pg_null then
    return "NULL"
  elseif _M.is_list(value) then
    local escaped = {}
    for _, val in ipairs(value[1]) do
      table.insert(escaped, _escape_literal(nil, val))
    end
    return "(" .. table.concat(escaped, ", ") .. ")"
  elseif int64.is_64bit(value) then
    return _escape_literal(nil, int64.to_string(value))
  else
    return _escape_literal(nil, value)
  end
end

function _M.escape_identifier(value)
  return _escape_identifier(nil, value)
end

function _M.setup_type_casting(pg)
  -- By default, pgmoon treats bigint values as normal lua numbers, which can
  -- lose precision: https://github.com/leafo/pgmoon/issues/48
  --
  -- To solve this, we'll cast PostgreSQL bigint values into a LuaJIT's FFI 64
  -- bit integers (int64_t), since we're only targeting LuaJIT.
  pg:set_type_oid(20, "bigint_int64")
  pg.type_deserializers.bigint_int64 = function(_, value)
    return int64.from_string(value)
  end

  -- pgmoon is currently missing support for handling PostgreSQL inet array
  -- types, so it doesn't know how to decode/encode these. So manually add
  -- inet[]'s oid (1041) so that they're handled as an array of strings.
  pg:set_type_oid(1041, "array_string")
end

function _M.connect()
  -- Try connecting a few times in case PostgreSQL is being restarted or
  -- starting up.
  --
  -- Note that pgmoon.new also needs to be inside the retry-loop, otherwise
  -- "the database system is starting up" errors from postgresql can lead to a
  -- nil socket inside pgmoon's internals on the next retry.
  local pg, ok, err
  for _ = 1, 5 do
    pg = pgmoon.new(db_config)
    ok, err = pg:connect()
    if not ok then
      ngx.log(ngx.ERR, "failed to connect to database: ", err)
      ngx.sleep(0.1)
    else
      break
    end
  end

  if not ok then
    return nil, err
  end

  _M.setup_type_casting(pg)

  -- The first time this socket is used (but not when reusing keepalive
  -- sockets), setup any session variables on the connection.
  if pg.sock:getreusedtimes() == 0 then
    local queries = {
      -- Set an application name for connection details.
      "SET SESSION application_name = 'api-umbrella'",

      -- Always use UTC.
      "SET SESSION timezone = 'UTC'",
    }
    for _, query in ipairs(queries) do
      ngx.log(ngx.NOTICE, query)
      local query_result, query_err = pg:query(query)
      if not query_result then
        ngx.log(ngx.ERR, "postgresql query error: ", query_err)
      end
    end
  end

  return pg
end

function _M.query(query, ...)
  local pg = _M.connect()
  if not pg then
    return nil, "connection error"
  end

  local num_values = select("#", ...)
  if num_values > 0 then
    if not ngx.re.match(query, [[\$]] .. num_values, "jo") then
      return nil, "bind variables not found"
    end

    local escaped_values = {}
    for i = 1, num_values do
      local value = select(i, ...)
      table.insert(escaped_values, _M.escape_literal(value))
    end

    local _, gsub_err
    query, _, gsub_err = ngx.re.gsub(query, [[\$(\d+)]], function(match)
      local index = assert(tonumber(match[1]))
      return escaped_values[index]
    end, "jo")
    if gsub_err then
      ngx.log(ngx.ERR, "regex error: ", gsub_err)
    end
  end

  local app_env = config["app_env"]
  if app_env == "development" or app_env == "test" then
    ngx.log(ngx.NOTICE, query)
  end
  local result, err = pg:query(query)
  if not result then
    ngx.log(ngx.ERR, "postgresql query error: ", err)
  end

  local keepalive_ok, keepalive_err = pg:keepalive()
  if not keepalive_ok then
    ngx.log(ngx.ERR, "postgresql keepalive error: ", keepalive_err)
  end

  return result, err
end

function _M.insert(table_name, values)
  local query = "INSERT INTO " .. _M.escape_identifier(table_name) .. " " .. encode_values(values)
  return _M.query(query)
end

function _M.update(table_name, where, values)
  local query = "UPDATE " .. _M.escape_identifier(table_name) .. " SET " .. encode_assigns(values) .. " WHERE " .. encode_assigns(where)
  return _M.query(query)
end

function _M.delete(table_name, where)
  local query = "DELETE FROM " .. _M.escape_identifier(table_name) .. " WHERE " .. encode_assigns(where)
  return _M.query(query)
end

return _M
