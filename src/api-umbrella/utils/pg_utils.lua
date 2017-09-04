local pgmoon = require "pgmoon"

local _escape_literal = pgmoon.Postgres.escape_literal
local _escape_identifier = pgmoon.Postgres.escape_identifier

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
  if _M.is_list(value) then
    local escaped = {}
    for _, val in ipairs(value[1]) do
      table.insert(escaped, _escape_literal(nil, val))
    end
    return "(" .. table.concat(escaped, ", ") .. ")"
  else
    return _escape_literal(nil, value)
  end
end

function _M.escape_identifier(value)
  return _escape_identifier(nil, value)
end

function _M.connect()
  local pg = pgmoon.new(db_config)

  local ok, err
  for _ = 1, 3 do
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

  ngx.log(ngx.NOTICE, query)
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
