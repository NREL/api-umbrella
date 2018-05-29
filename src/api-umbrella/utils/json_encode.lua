local cjson = require "cjson"
local cjson_encode = cjson.encode

-- Increase precision in order to handle encoding bigger numbers.
cjson.encode_number_precision(16)

return function(data)
  return cjson_encode(data)
end
