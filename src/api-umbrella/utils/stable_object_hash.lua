local json_encode = require "api-umbrella.utils.json_encode"
local is_array = require "api-umbrella.utils.is_array"
local table_keys = require("pl.tablex").keys
local is_hash = require "api-umbrella.utils.is_hash"

local function ordered_data(object)
  local ordered_object = object

  if is_hash(object) then
    -- Sort the hashes by the keys in alphabetical order. This ensures the YAML
    -- output is always consistently sorted.
    ordered_object = {}

    local ordered_keys = {}
    for _, key in ipairs(table_keys(object)) do
      table.insert(ordered_keys, key)
    end
    table.sort(ordered_keys)

    for index, key in ipairs(ordered_keys) do
      ordered_object[index] = {
        key,
        ordered_data(object[key]),
      }
    end
  elseif is_array(object) then
    ordered_object = {}
    for index, value in ipairs(object) do
      ordered_object[index] = ordered_data(value)
    end
  end

  return ordered_object
end

return function(data)
  local dump = json_encode({ ordered_data(data) })
  ngx.log(ngx.ERR, "DUMP: ", dump)

  return ngx.md5(dump)
end
