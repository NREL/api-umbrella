local cjson = require "cjson"

local json_empty_array = cjson.empty_array_mt
local json_null = cjson.null

-- When returning JSON, we need to be explicit with how empty arrays get
-- serialized from Lua (since in Lua, there's no way to distinguish whether an
-- empty table is array-like or hash-like). So this function ensures the given
-- fields are consistently handled as arrays in the serialized JSON.
return function(data, array_fields, options)
  assert(data)
  assert(array_fields)

  -- Accept an option to turn empty arrays into JSON null values (this is for
  -- how the JSON gets serialized for publishing the backend config).
  local nullify_empty_arrays = false
  if options and options["nullify_empty_arrays"] then
    nullify_empty_arrays = true
  end

  for _, field in ipairs(array_fields) do
    if nullify_empty_arrays then
      local value = data[field]
      if type(value) == "table" and next(value) == nil then
        data[field] = json_null
      end
    else
      -- Set the special metatable to ensure an empty Lua table gets serialized
      -- as an empty JSON array, rather than an empty JSON object.
      setmetatable(data[field], json_empty_array)
    end
  end
end
