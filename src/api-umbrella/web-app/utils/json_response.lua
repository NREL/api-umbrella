local json_encode = require "api-umbrella.utils.json_encode"

return function(self, obj)
  self.res.headers["Content-Type"] = "application/json; charset=utf-8"
  if type(obj) == "string" then
    self.res.content = obj
  else
    self.res.content = json_encode(obj)
  end
  return { layout = false }
end
