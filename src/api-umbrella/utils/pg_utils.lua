local encode_array = require("pgmoon.arrays").encode_array
local encode_json = require("pgmoon.json").encode_json

local _M = {}

local function escape_value(pg, value)
  if type(value) == "function" then
    local escaped, escaped_value = value()
    if escaped == "escaped" then
      return escaped_value
    else
      return pg:escape_literal(escaped_value)
    end
  else
    return pg:escape_literal(value)
  end
end

local function encode_values(pg, values)
  local escaped_columns = {}
  local escaped_values = {}
  for column, value in pairs(values) do
    table.insert(escaped_columns, pg:escape_identifier(column))
    table.insert(escaped_values, escape_value(pg, value))
  end

  return "(" .. table.concat(escaped_columns, ", ") .. ") VALUES (" .. table.concat(escaped_values, ", ") .. ")"
end

local function encode_assigns(pg, values)
  local escaped_assigns = {}
  for column, value in pairs(values) do
    table.insert(escaped_assigns, pg:escape_identifier(column) .. " = " .. escape_value(pg, value))
  end

  return table.concat(escaped_assigns, ", ")
end

function _M.as_array(value)
  return function()
    return "escaped", encode_array(value)
  end
end

function _M.as_json(value)
  return function()
    return "escaped", encode_json(value)
  end
end

function _M.query(pg, query, ...)
  local num_values = select("#", ...)
  if num_values > 0 then
    if not ngx.re.match(query, [[\$]] .. num_values, "jo") then
      return nil, "bind variables not found"
    end

    local escaped_values = {}
    for i = 1, num_values do
      local value = select(i, ...)
      table.insert(escaped_values, escape_value(pg, value))
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
  return pg:query(query)
end

function _M.insert(pg, table_name, values)
  local query = "INSERT INTO " .. pg:escape_identifier(table_name) .. " " .. encode_values(pg, values)
  return _M.query(pg, query)
end

function _M.update(pg, table_name, where, values)
  local query = "UPDATE " .. pg:escape_identifier(table_name) .. " SET " .. encode_assigns(pg, values) .. " WHERE " .. encode_assigns(pg, where)
  return _M.query(pg, query)
end

return _M
