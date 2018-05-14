local is_array = require "api-umbrella.utils.is_array"

-- Like deep_merge_overwrite_arrays, but only assigns values from the source to
-- the destination if the destination is nil. So any existing values on the
-- destination object will be retained.
local function deep_defaults(dest, src)
  if not src then return dest end

  for key, value in pairs(src) do
    if type(value) == "table" and type(dest[key]) == "table" then
      if is_array(value) or is_array(dest[key]) then
        if dest[key] == nil then
          dest[key] = value
        end
      else
        deep_defaults(dest[key], src[key])
      end
    else
      if dest[key] == nil then
        dest[key] = value
      end
    end
  end

  return dest
end

return deep_defaults
