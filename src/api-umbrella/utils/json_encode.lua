local cjson = require "cjson"
local cjson_encode = cjson.encode

-- Increase precision in order to handle encoding bigger numbers.
cjson.encode_number_precision(16)

return cjson_encode
