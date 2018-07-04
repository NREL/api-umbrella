local json_null = require("cjson").null

-- cjson reads JSON null values as a special cjson.null object. In our case,
-- we just want to get rid of null values, so recursively walk the JSON config
-- and get rid of any of these special cjson.null values.
local function nillify_json_nulls(table)
  if not table then return end

  for key, value in pairs(table) do
    if value == json_null then
      table[key] = nil
    elseif type(value) == "table" then
      table[key] = nillify_json_nulls(value)
    end
  end

  return table
end

return nillify_json_nulls
