local _M = {}

local inspect = require "inspect"
local lyaml = require "lyaml"
local utils = require "pl.utils"

local log = ngx.log
local ERR = ngx.ERR

-- lyaml reads YAML null values as a special "LYAML null" object. In our case,
-- we just want to get rid of null values, so recursively walk the YAML config
-- and get rid of any of these special "LYAML null" values.
function nillify_yaml_nulls(table)
  if not table then return end

  for key, value in pairs(table) do
    if (getmetatable(value) or {})._type == "LYAML null" then
      table[key] = nil
    elseif type(value) == "table" then
      table[key] = nillify_yaml_nulls(value)
    end
  end

  return table
end

function _M.parse()
  local f, err = io.open("/tmp/runtime_config_test.yml", "rb")
  if err then
    return log(ERR, "failed to open config file: ", err)
  end

  local content = f:read("*all")
  f:close()

  local data = lyaml.load(content)
  nillify_yaml_nulls(data)

  return data
end

return _M
