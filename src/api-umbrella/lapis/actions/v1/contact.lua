local Contact = require "api-umbrella.lapis.models.contact"
local capture_errors_json_full = require("api-umbrella.utils.lapis_helpers").capture_errors_json_full
local iso8601 = require "api-umbrella.utils.iso8601"
local json_params = require("lapis.application").json_params
local lapis_json = require "api-umbrella.utils.lapis_json"
local nillify_json_nulls = require "api-umbrella.utils.nillify_json_nulls"

local _M = {}

function _M.create(self)
  assert(Contact:authorized_deliver(_M.contact_params(self)))
  local response = {
    submitted = iso8601.format_timestamp(ngx.now()),
  }

  return lapis_json(self, response)
end

function _M.contact_params(self)
  local params = {}
  if self.params and self.params["contact"] then
    local input = self.params["contact"]
    params = nillify_json_nulls({
      name = input["name"],
      email = input["email"],
      api = input["api"],
      subject = input["subject"],
      message = input["message"],
    })
  end

  return params
end


return function(app)
  app:post("/api-umbrella/v1/contact(.:format)", capture_errors_json_full(json_params(_M.create)))
end
