-- Determine if the table is an array.
--
-- In benchmarks, appears faster than moses.isArray implementation.
return function(obj)
  if type(obj) ~= "table" then
    return false
  end

  local count = 1
  for key, _ in pairs(obj) do
    if key ~= count then
      return false
    end
    count = count + 1
  end

  -- If it's an empty table, we don't have any way to determine if it's an
  -- array or not. But since it could be, return true.
  if count == 1 then
    return true
  end

  return true
end
