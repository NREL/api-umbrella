-- lyaml reads YAML null values as a special "LYAML null" object. In our case,
-- we just want to get rid of null values, so recursively walk the YAML config
-- and get rid of any of these special "LYAML null" values.
local function nillify_yaml_nulls(table)
  if not table then return end

  for key, value in pairs(table) do
    if (getmetatable(value) or {})._type == "LYAML null" then
      table[key] = nil
    elseif type(value) == "table" then
      table[key] = nillify_yaml_nulls(value)
    end
  end

  return table
end

return nillify_yaml_nulls
