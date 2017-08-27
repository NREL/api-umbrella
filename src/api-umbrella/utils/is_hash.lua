local is_array = require "api-umbrella.utils.is_array"

-- Determine if the table is hash-like (not an array).
return function(obj)
  if type(obj) ~= "table" then
    return false
  end

  -- If it's an empty table, we don't have any way to determine if it's an hash
  -- or not. But since it could be, return true.
  if #obj == 0 then
    return true
  end

  if is_array(obj) then
    return false
  end

  return true
end
