local cjson = require "cjson"
local db = require "lapis.db"
local db_null = db.NULL
local json_null = cjson.null

-- cjson reads JSON null values as a special cjson.null object. Turn these into
-- db.NULL objects for use with Lapis.
local function dbify_json_nulls(table)
  if not table then return end

  for key, value in pairs(table) do
    if value == json_null then
      table[key] = db_null
    elseif type(value) == "table" then
      table[key] = dbify_json_nulls(value)
    end
  end

  return table
end

return dbify_json_nulls
