local function flatten(array)
  local flat = {}
  for index = 1, table.maxn(array) do
    local value = array[index]
    if type(value) == "table" then
      local sub_flat = flatten(value)
      for _, sub_value in ipairs(sub_flat) do
        table.insert(flat, sub_value)
      end
    else
      table.insert(flat, value)
    end
  end

  return flat
end

return flatten
