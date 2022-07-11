local dkjson_encode = require("dkjson").encode
local is_hash = require "api-umbrella.utils.is_hash"

-- Recusrively set the json output order for all hash-like tables to
-- alphabetical based on the order of the keys (so the JSON output is stable for
-- this sorted keys function).
local function set_jsonorder(var)
  if type(var) ~= "table" then
    return var
  end

  local keys = {}
  for key, value in pairs(var) do
    table.insert(keys, key)

    if type(value) == "table" then
      var[key] = set_jsonorder(value)
    end
  end

  if is_hash(var) then
    table.sort(keys)
    setmetatable(var, { __jsonorder = keys })
  end

  return var
end

return function(data)
  set_jsonorder(data)
  return dkjson_encode(data)
end
