local respond_to = require("lapis.application").respond_to
local db = require "lapis.db"
local ApiBackend = require "api-umbrella.lapis.models.api_backend"
local is_array = require "api-umbrella.utils.is_array"
local dbify_json_nulls = require "api-umbrella.utils.dbify_json_nulls"
local lapis_json = require "api-umbrella.utils.lapis_json"
local json_params = require("lapis.application").json_params
local lapis_helpers = require "api-umbrella.utils.lapis_helpers"
local lapis_datatables = require "api-umbrella.utils.lapis_datatables"

local capture_errors_json = lapis_helpers.capture_errors_json

local _M = {}

function _M.index(self)
  return lapis_datatables.index(self, ApiBackend, {
    joins = {
      "LEFT JOIN LATERAL jsonb_array_elements(config->'url_matches') AS config_url_matches ON true",
      "LEFT JOIN LATERAL jsonb_array_elements(config->'servers') AS config_servers ON true",
    },
    search_fields = {
      "name",
      db.raw("config->>'frontend_host'"),
      db.raw("config->>'backend_host'"),
      db.raw("config_url_matches->>'backend_prefix'"),
      db.raw("config_url_matches->>'frontend_prefix'"),
      db.raw("config_servers->>'host'"),
    },
  })
end

function _M.show(self)
  local response = {
    api = self.api_backend:as_json(),
  }

  return lapis_json(self, response)
end

function _M.create(self)
  local api_backend = assert(ApiBackend:create(_M.api_backend_params(self)))
  local response = {
    api = api_backend:as_json(),
  }

  self.res.status = 201
  return lapis_json(self, response)
end

function _M.update(self)
  self.api_backend:update(_M.api_backend_params(self))

  return { status = 204 }
end

function _M.destroy(self)
  self.api_backend:delete()

  return { status = 204 }
end

function _M.move_after(self)
end

function _M.api_backend_params(self)
  local params = {}
  if self.params and self.params["api"] then
    local input = self.params["api"]
    params = dbify_json_nulls({
      name = input["name"],
      sort_order = input["sort_order"],
      config = {
        backend_protocol = input["backend_protocol"],
        frontend_host = input["frontend_host"],
        backend_host = input["backend_host"],
        balance_algorithm = input["balance_algorithm"],
      },
    })

    if is_array(input["servers"]) then
      params["config"]["servers"] = {}
      for _, input_server in ipairs(input["servers"]) do
        table.insert(params["config"]["servers"], dbify_json_nulls({
          id = input_server["id"],
          host = input_server["host"],
          port = input_server["port"],
        }))
      end
    end

    if is_array(input["url_matches"]) then
      params["config"]["url_matches"] = {}
      for _, input_match in ipairs(input["url_matches"]) do
        table.insert(params["config"]["url_matches"], dbify_json_nulls({
          id = input_match["id"],
          host = input_match["frontend_prefix"],
          port = input_match["backend_prefix"],
        }))
      end
    end
  end

  return params
end

return function(app)
  app:match("/api-umbrella/v1/apis/:id(.:format)", respond_to({
    before = function(self)
      self.api_backend = ApiBackend:find(self.params["id"])
      if not self.api_backend then
        self:write({"Not Found", status = 404})
      end
    end,
    GET = _M.show,
    POST = capture_errors_json(json_params(_M.update)),
    PUT = capture_errors_json(json_params(_M.update)),
    DELETE = _M.destroy,
  }))

  app:get("/api-umbrella/v1/apis(.:format)", _M.index)
  app:post("/api-umbrella/v1/apis(.:format)", capture_errors_json(json_params(_M.create)))
  app:put("/api-umbrella/v1/apis/:id/move_after(.:format)", _M.move_after)
end
