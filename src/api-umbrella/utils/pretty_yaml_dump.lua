local OrderedMap = require "pl.OrderedMap"
local is_array = require "api-umbrella.utils.is_array"
local is_hash = require "api-umbrella.utils.is_hash"
local lyaml = require "lyaml"

local gsub = ngx.re.gsub

local function pretty_data(object)
  local pretty_object = object

  if is_hash(object) then
    -- Sort the hashes by the keys in alphabetical order. This ensures the YAML
    -- output is always consistently sorted.
    pretty_object = OrderedMap()
    for key, value in pairs(object) do
      pretty_object:set(key, pretty_data(value))
    end
    pretty_object:sort()
  elseif is_array(object) then
    pretty_object = {}
    for index, value in ipairs(object) do
      pretty_object[index] = pretty_data(value)
    end
  elseif type(object) == "userdata" then
    -- Remove special userdata types, like json.null, since lyaml can't dump
    -- these.
    pretty_object = nil
  end

  return pretty_object
end

return function(data)
  local dump = lyaml.dump({ pretty_data(data) })

  -- Remove the "---" document separator from the beginning.
  dump = gsub(dump, [[\A---\s*\n?]], "", "ijo")

  -- Remove the "..." end of document separator from the end.
  dump = gsub(dump, [[\n?\.\.\.\s*\n?\z]], "", "ijo")

  return dump
end
