local is_array = require "api-umbrella.utils.is_array"
local is_empty = require "api-umbrella.utils.is_empty"

local function deep_merge_overwrite_arrays(dest, src)
  if not src then return dest end

  for src_key, src_value in pairs(src) do
    if type(src_value) == "table" and type(dest[src_key]) == "table" then
      -- Overwrite array values, but don't count empty tables as arrays (since
      -- they could also be hashes, since there's no way to really distinguish
      -- an empty table in lua).
      if (is_array(src_value) and not is_empty(src_value)) or (is_array(dest[src_key]) and not is_empty(dest[src_key])) then
        dest[src_key] = src_value
      else
        deep_merge_overwrite_arrays(dest[src_key], src[src_key])
      end
    else
      dest[src_key] = src_value
    end
  end

  return dest
end

return deep_merge_overwrite_arrays
