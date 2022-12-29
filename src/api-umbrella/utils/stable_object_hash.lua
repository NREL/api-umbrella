local json_encode_sorted_keys = require "api-umbrella.utils.json_encode_sorted_keys"

return function(data)
  local dump = json_encode_sorted_keys(data)
  return ngx.md5(dump)
end
