local cjson = require "cjson"

local json_encode = cjson.encode

return function(self, obj)
  self.res.headers["Content-Type"] = "application/json"
  self.res.content = json_encode(obj)
  return { layout = false }
end
