local json_null = require("cjson").null
local lapis_json_params = require("lapis.application").json_params

return function(fn, wrapper_key)
  return lapis_json_params(function(self, ...)
    if self.json and (not self.params[wrapper_key] or self.params[wrapper_key] == json_null) then
      self.params[wrapper_key] = self.json
    end

    return fn(self, ...)
  end)
end
