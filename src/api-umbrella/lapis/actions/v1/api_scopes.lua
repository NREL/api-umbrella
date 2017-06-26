local respond_to = require("lapis.application").respond_to
local ApiScope = require "api-umbrella.lapis.models.api_scope"
local dbify_json_nulls = require "api-umbrella.utils.dbify_json_nulls"
local json_params = require("lapis.application").json_params
local app_helpers = require "lapis.application"

local capture_errors = app_helpers.capture_errors
local capture_errors_json = function(fn)
  return capture_errors(fn, function(self)
    return {
      status = 422,
      json = {
        errors = self.errors
      }
    }
  end)
end

local _M = {}

function _M.index(self)
  local api_scopes = ApiScope:select()

  local response = {
    draw = tonumber(self.params["draw"]),
    recordsTotal = #api_scopes,
    recordsFiltered = #api_scopes,
    data = {},
  }

  for _, api_scope in ipairs(api_scopes) do
    table.insert(response["data"], api_scope:as_json())
  end

  return { json = response }
end

function _M.show(self)
  local response = {
    api_scope = self.api_scope:as_json(),
  }

  return { json = response }
end

function _M.create(self)
  local api_scope = assert(ApiScope:create(_M.api_scope_params(self)))
  local response = {
    api_scope = api_scope:as_json(),
  }

  return { status = 201, json = response }
end

function _M.update(self)
  self.api_scope:update(_M.api_scope_params(self))

  return { status = 204 }
end

function _M.destroy(self)
  self.api_scope:delete()

  return { status = 204 }
end

function _M.api_scope_params(self)
  local params = {}
  if self.params and self.params["api_scope"] then
    params = dbify_json_nulls({
      name = self.params["api_scope"]["name"],
      host = self.params["api_scope"]["host"],
      path_prefix = self.params["api_scope"]["path_prefix"],
    })
  end

  return params
end

return function(app)
  app:match("/api-umbrella/v1/api_scopes/:id(.:format)", respond_to({
    before = function(self)
      self.api_scope = ApiScope:find(self.params["id"])
      if not self.api_scope then
        self:write({"Not Found", status = 404})
      end
    end,
    GET = _M.show,
    POST = capture_errors_json(json_params(_M.update)),
    PUT = capture_errors_json(json_params(_M.update)),
    DELETE = _M.destroy,
  }))

  app:get("/api-umbrella/v1/api_scopes(.:format)", _M.index)
  app:post("/api-umbrella/v1/api_scopes(.:format)", capture_errors_json(json_params(_M.create)))
end
