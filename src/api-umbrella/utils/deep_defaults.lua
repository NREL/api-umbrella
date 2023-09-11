local is_array = require "api-umbrella.utils.is_array"
local is_empty = require "api-umbrella.utils.is_empty"

-- Like deep_merge_overwrite_arrays, but only assigns values from the source to
-- the destination if the destination is nil. So any existing values on the
-- destination object will be retained.
local function deep_defaults(dest, src)
  if not src then return dest end

  for src_key, src_value in pairs(src) do
    if type(src_value) == "table" and type(dest[src_key]) == "table" then
      if is_array(src_value) or is_array(dest[src_key]) then
        if dest[src_key] == nil or is_empty(dest[src_key]) then
          dest[src_key] = src_value
        end
      else
        deep_defaults(dest[src_key], src[src_key])
      end
    else
      if dest[src_key] == nil then
        dest[src_key] = src_value
      end
    end
  end

  return dest
end

return deep_defaults
