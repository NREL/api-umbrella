return function(table)
  local inverted = {}
  for key, value in pairs(table) do
    inverted[value] = key
  end

  return inverted
end
