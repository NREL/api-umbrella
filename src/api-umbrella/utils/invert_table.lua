return function(table)
  local numItems = 0
  local inverted = {}
  for key, value in pairs(table) do
    if type(value)=="string" then
      inverted[value] = key
    else
      for k,v in pairs(value) do
        numItems = numItems + 1
      end
      if numItems > 1 then
        value = value["name"]
      end
      inverted[value] = key
    end
  end
  return inverted
end