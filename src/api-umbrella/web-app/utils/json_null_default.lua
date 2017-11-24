local json_null = require("cjson").null

-- Provides a default json null value if the value isn't set (but ensures
-- "false" boolean values are retained).
return function(value)
  if value or value == false then
    return value
  else
    return json_null
  end
end
