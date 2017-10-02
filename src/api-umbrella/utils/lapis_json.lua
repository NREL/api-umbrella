local cjson = require "cjson"

local json_encode = cjson.encode

return function(self, obj)
  self.res.headers["Content-Type"] = "application/json"
  if type(obj) == "string" then
    self.res.content = obj
  else
    self.res.content = json_encode(obj)
  end
  return { layout = false }
end
