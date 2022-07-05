local rapidjson_encode = require("rapidjson").encode

return function(data)
  return rapidjson_encode(data, { sort_keys = true })
end
