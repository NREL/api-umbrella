local respond_to = require("lapis.application").respond_to
local ApiScope = require "api-umbrella.lapis.models.api_scope"
local db = require "lapis.db"
local dbify_json_nulls = require "api-umbrella.utils.dbify_json_nulls"
local lapis_json = require "api-umbrella.utils.lapis_json"
local json_params = require("lapis.application").json_params
local cjson = require "cjson"
local tablex = require "pl.tablex"
local types = require "pl.types"
local app_helpers = require "lapis.application"

local is_empty = types.is_empty
local table_keys = tablex.keys

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
  local query = {
    where = {},
    clause = {},
    order = {},
  }

  if self.params["search"] and not is_empty(self.params["search"]["value"]) then
    local fields = { "id", "name", "host", "path_prefix" }
    local search_sql = {}
    for _, field in ipairs(fields) do
      local value, _, gsub_err = ngx.re.gsub(self.params["search"]["value"], "[%_\\\\]", "\\$0", "jo")
      if gsub_err then
        ngx.log(ngx.ERR, "regex error: ", gsub_err)
      end

      table.insert(search_sql, db.interpolate_query(db.escape_identifier(field) .. "::text ILIKE '%' || ? || '%'", value))
    end
    table.insert(query["where"], "(" .. table.concat(search_sql, " OR ") .. ")")
  end

  local where
  if not is_empty(query["where"]) then
    where = "(" .. table.concat(query["where"], ") AND (") .. ")"
  end
  local total_count = ApiScope:count(where)

  if is_empty(self.params["order"]) then
    table.insert(query["order"], "name ASC")
  else
    local orders = self.params["order"]
    local order_keys = {}
    for _, order_key in ipairs(table_keys(orders)) do
      table.insert(order_keys, tonumber(order_key))
    end
    table.sort(order_keys)
    for _, order_key in ipairs(order_keys) do
      local order = orders[tostring(order_key)]

      local column_name
      local column_index = order["column"]
      if self.params["columns"] then
        local column = self.params["columns"][column_index]
        if column then
          column_name = column["data"]
        end
      end

      local dir
      if order["dir"] and string.lower(order["dir"]) == "desc" then
        dir = "DESC"
      else
        dir = "ASC"
      end

      if column_name and dir then
        table.insert(query["order"], db.escape_identifier(column_name) .. " " .. dir)
      end
    end
  end

  if not is_empty(self.params["length"]) then
    table.insert(query["clause"], db.interpolate_query("LIMIT ?", tonumber(self.params["length"])))
  end

  if not is_empty(self.params["start"]) then
    table.insert(query["clause"], db.interpolate_query("OFFSET ?", tonumber(self.params["start"])))
  end

  if where then
    where = "WHERE " .. where
  end

  if not is_empty(query["order"]) then
    where = (where or "") .. " ORDER BY " .. table.concat(query["order"], ", ")
  end

  if not is_empty(query["clause"]) then
    where = (where or "") .. " " .. table.concat(query["clause"], " ")
  end

  local api_scopes = ApiScope:select(where)

  local response = {
    draw = tonumber(self.params["draw"]) or 0,
    recordsTotal = total_count,
    recordsFiltered = total_count,
    data = {},
  }

  for _, api_scope in ipairs(api_scopes) do
    table.insert(response["data"], api_scope:as_json())
  end

  setmetatable(response["data"], cjson.empty_array_mt)

  return lapis_json(self, response)
end

function _M.show(self)
  local response = {
    api_scope = self.api_scope:as_json(),
  }

  return lapis_json(self, response)
end

function _M.create(self)
  local api_scope = assert(ApiScope:create(_M.api_scope_params(self)))
  local response = {
    api_scope = api_scope:as_json(),
  }

  self.res.status = 201
  return lapis_json(self, response)
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
