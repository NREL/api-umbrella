-- Determine if the table is an array.
--
-- In benchmarks, appears faster than moses.isArray implementation.
return function(obj)
  if type(obj) ~= "table" then return false end

  local count = 1
  for key, _ in pairs(obj) do
    if key ~= count then
      return false
    end
    count = count + 1
  end

  return true
end
