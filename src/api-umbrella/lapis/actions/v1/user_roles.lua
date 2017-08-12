local cjson = require "cjson"
local lapis_json = require "api-umbrella.utils.lapis_json"

local _M = {}

function _M.index(self)
  local response = {
    user_roles = {},
  }
  setmetatable(response["user_roles"], cjson.empty_array_mt)

  return lapis_json(self, response)
end

return function(app)
  app:get("/api-umbrella/v1/user_roles(.:format)", _M.index)
end
