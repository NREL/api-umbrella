local respond_to = require("lapis.application").respond_to
local cjson = require "cjson"
local dbify_json_nulls = require "api-umbrella.utils.dbify_json_nulls"
local lapis_json = require "api-umbrella.utils.lapis_json"
local json_params = require("lapis.application").json_params
local lapis_helpers = require "api-umbrella.utils.lapis_helpers"
local lapis_datatables = require "api-umbrella.utils.lapis_datatables"

local capture_errors_json = lapis_helpers.capture_errors_json

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
