local is_array = require "api-umbrella.utils.is_array"
local is_empty = require "api-umbrella.utils.is_empty"

local function deep_merge_overwrite_arrays(dest, src)
  if not src then return dest end

  for key, value in pairs(src) do
    if type(value) == "table" and type(dest[key]) == "table" then
      -- Overwrite array values, but don't count empty tables as arrays (since
      -- they could also be hashes, since there's no way to really distinguish
      -- an empty table in lua).
      if (is_array(value) and not is_empty(value)) or (is_array(dest[key]) and not is_empty(dest[key])) then
        dest[key] = value
      else
        deep_merge_overwrite_arrays(dest[key], src[key])
      end
    else
      dest[key] = value
    end
  end

  return dest
end

return deep_merge_overwrite_arrays
