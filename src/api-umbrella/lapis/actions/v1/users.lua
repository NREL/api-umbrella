local respond_to = require("lapis.application").respond_to
local flatten_headers = require "api-umbrella.utils.flatten_headers"
local ApiUser = require "api-umbrella.lapis.models.api_user"
local dbify_json_nulls = require "api-umbrella.utils.dbify_json_nulls"
local lapis_json = require "api-umbrella.utils.lapis_json"
local json_params = require("lapis.application").json_params
local lapis_helpers = require "api-umbrella.utils.lapis_helpers"
local lapis_datatables = require "api-umbrella.utils.lapis_datatables"
local types = require "pl.types"

local is_empty = types.is_empty
local capture_errors_json = lapis_helpers.capture_errors_json

local _M = {}

function _M.index(self)
  return lapis_datatables.index(self, ApiUser, {
    search_fields = {
      "first_name",
      "last_name",
      "email",
      "api_key",
      "registration_source",
      "roles",
    },
  })
end

function _M.show(self)
  local response = {
    user = self.api_user:as_json(),
  }

  return lapis_json(self, response)
end

function _M.create(self)
  local request_headers = flatten_headers(ngx.req.get_headers())

  local user_params = _M.api_user_params(self)
  user_params["registration_ip"] = ngx.var.remote_addr
  user_params["registration_user_agent"] = request_headers["user-agent"]
  user_params["registration_referer"] = request_headers["referer"]
  user_params["registration_origin"] = request_headers["origin"]
  if self.params and self.params["user"] and not is_empty(self.params["user"]["registration_source"]) then
    user_params["registration_source"] = self.params["user"]["registration_source"]
  else
    user_params["registration_source"] = "api"
  end

  local api_user = assert(ApiUser:create(user_params))
  local response = {
    user = api_user:as_json(),
  }

  self.res.status = 201
  return lapis_json(self, response)
end

function _M.update(self)
  self.api_user:update(_M.api_user_params(self))

  return { status = 204 }
end

function _M.destroy(self)
  assert(self.api_user:delete())

  return { status = 204 }
end

function _M.api_user_params(self)
  local params = {}
  if self.params and self.params["user"] then
    local input = self.params["user"]
    params = dbify_json_nulls({
      email = input["email"],
      first_name = input["first_name"],
      last_name = input["last_name"],
      use_description = input["use_description"],
    })
  end

  return params
end

return function(app)
  app:match("/api-umbrella/v1/users/:id(.:format)", respond_to({
    before = function(self)
      self.api_user = ApiUser:find(self.params["id"])
      if not self.api_user then
        self:write({"Not Found", status = 404})
      end
    end,
    GET = _M.show,
    POST = capture_errors_json(json_params(_M.update)),
    PUT = capture_errors_json(json_params(_M.update)),
    DELETE = _M.destroy,
  }))

  app:get("/api-umbrella/v1/users(.:format)", _M.index)
  app:post("/api-umbrella/v1/users(.:format)", capture_errors_json(json_params(_M.create)))
end
