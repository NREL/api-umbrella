local is_array = require "api-umbrella.utils.is_array"

-- Determine if the table is hash-like (not an array).
return function(obj)
  if type(obj) ~= "table" then return false end
  if is_array(obj) then return false end

  return true
end
