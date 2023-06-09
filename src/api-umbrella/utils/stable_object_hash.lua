local json_encode_sorted_keys = require "api-umbrella.utils.json_encode_sorted_keys"

local md5 = ngx.md5

return function(data)
  local dump = json_encode_sorted_keys(data)
  return md5(dump)
end
