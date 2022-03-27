local config = require "api-umbrella.proxy.models.file_config"
local int64 = require "api-umbrella.utils.int64"
local pgmoon = require "pgmoon"
local random_token = require "api-umbrella.utils.random_token"

-- Preload modules that pgmoon may require at query() time.
require "pgmoon.arrays"
require "pgmoon.json"

local _encode_bytea = pgmoon.Postgres.encode_bytea
local _escape_identifier = pgmoon.Postgres.escape_identifier
local _escape_literal = pgmoon.Postgres.escape_literal
local pg_null = pgmoon.Postgres.NULL

local _M = {}

_M.db_config = {
  host = config["postgresql"]["host"],
  port = config["postgresql"]["port"],
  database = config["postgresql"]["database"],
  user = config["postgresql"]["username"],
  password = config["postgresql"]["password"],
  ssl = config["postgresql"]["ssl"],
  ssl_verify = config["postgresql"]["ssl_verify"],
  ssl_required = config["postgresql"]["ssl_required"],
}

local BYTEA_METATABLE = {}
local IDENTIFIER_METATABLE = {}
local LIST_METATABLE = {}
local RAW_METATABLE = {}

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

local function encode_where(values)
  local escaped_assigns = {}
  for column, value in pairs(values) do
    table.insert(escaped_assigns, _M.escape_identifier(column) .. " = " .. _M.escape_literal(value))
  end

  return table.concat(escaped_assigns, " AND ")
end

function _M.bytea(value)
  return setmetatable({ value }, BYTEA_METATABLE)
end

function _M.is_bytea(value)
  return getmetatable(value) == BYTEA_METATABLE
end

function _M.identifier(value)
  return setmetatable({ value }, IDENTIFIER_METATABLE)
end

function _M.is_identifier(value)
  return getmetatable(value) == IDENTIFIER_METATABLE
end

function _M.list(value)
  return setmetatable({ value }, LIST_METATABLE)
end

function _M.is_list(value)
  return getmetatable(value) == LIST_METATABLE
end

function _M.raw(value)
  return setmetatable({ value }, RAW_METATABLE)
end

function _M.is_raw(value)
  return getmetatable(value) == RAW_METATABLE
end

function _M.escape_like(value)
  return ngx.re.gsub(value, "[\\\\%_]", "\\$0", "jo")
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
  elseif _M.is_raw(value) then
    return tostring(value[1])
  elseif int64.is_64bit(value) then
    return _escape_literal(nil, int64.to_string(value))
  elseif _M.is_bytea(value) then
    return _encode_bytea(nil, value[1])
  elseif _M.is_identifier(value) then
    return _escape_identifier(nil, value[1])
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
    pg = pgmoon.new(_M.db_config)
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
      "SET search_path = api_umbrella, public",

      -- Set an application name for connection details.
      "SET SESSION audit.application_name = 'api-umbrella'",

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

function _M.query(query, values, options)
  local pg = _M.connect()
  if not pg then
    return nil, "connection error"
  end

  if values then
    local escaped_values = {}
    for key, value in pairs(values) do
      escaped_values[key] = _M.escape_literal(value)
    end

    -- Find all bind variable syntax (":word") and replace with the appropriate
    -- variable. Be careful not to match "::word", so that we don't match
    -- postgres type casting (eg, "foo::date").
    local _, gsub_err
    query, _, gsub_err = ngx.re.gsub(query, [[(?<!:):(\w+)]], function(match)
      local key = match[1]
      local escaped_value = escaped_values[key] or "NULL"
      return escaped_value
    end)
    if gsub_err then
      ngx.log(ngx.ERR, "regex error: ", gsub_err)
    end
  end

  local app_env = config["app_env"]
  if app_env == "development" or app_env == "test" or (options and options["verbose"]) then
    local level = ngx.NOTICE
    if options and options["quiet"] then
      level = ngx.DEBUG
    end
    ngx.log(level, query)
    if options and options["verbose"] then
      print(query)
    end
  end
  local result, num_queries = pg:query(query)
  local err
  if not result then
    err = num_queries
    ngx.log(ngx.ERR, "postgresql query error: ", err)
  end

  local keepalive_ok, keepalive_err = pg:keepalive()
  if not keepalive_ok then
    ngx.log(ngx.ERR, "postgresql keepalive error: ", keepalive_err)
  end

  if options and options["fatal"] and err then
    error(err)
  end

  return result, err
end

function _M.insert(table_name, values, options)
  local query = "INSERT INTO " .. _M.escape_identifier(table_name) .. " " .. encode_values(values)
  return _M.query(query, nil, options)
end

function _M.update(table_name, where, values, options)
  local query = "UPDATE " .. _M.escape_identifier(table_name) .. " SET " .. encode_assigns(values) .. " WHERE " .. encode_where(where)
  return _M.query(query, nil, options)
end

function _M.delete(table_name, where, options)
  local query = "DELETE FROM " .. _M.escape_identifier(table_name) .. " WHERE " .. encode_where(where)
  return _M.query(query, nil, options)
end

function _M.cursor_begin(query, values, cursor_size, options)
  local cursor_name = "cursor_" .. (ngx.now() * 1000) .. "_" .. random_token(16)
  local declare_sql = "DECLARE " .. cursor_name .. " NO SCROLL CURSOR WITHOUT HOLD FOR " .. query
  local fetch_sql = "FETCH " .. tonumber(cursor_size) .. " FROM " .. cursor_name

  local _, query_err = _M.query("BEGIN", nil, options)
  if query_err then
    return nil, query_err
  end

  _, query_err = _M.query(declare_sql, values, options)
  if query_err then
    _, query_err = _M.query("COMMIT", nil, options)
    if query_err then
      query_err = query_err .. " " .. query_err
    end

    return nil, query_err
  end

  return fetch_sql
end

function _M.cursor_close(options)
  local _, query_err = _M.query("COMMIT", nil, options)
  if query_err then
    return nil, query_err
  end
end

return _M
