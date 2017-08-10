local db = require "lapis.db"
local lapis_json = require "api-umbrella.utils.lapis_json"
local cjson = require "cjson"
local tablex = require "pl.tablex"
local types = require "pl.types"

local is_empty = types.is_empty
local table_keys = tablex.keys

local _M = {}

function _M.index(self, model, options)
  local query = {
    where = {},
    clause = {},
    order = {},
  }

  if self.params["search"] and not is_empty(self.params["search"]["value"]) then
    local search_sql = {}
    --table.insert(search_sql, db.interpolate_query("id = ?", self.params["search"]["value"]))
    if options["search_fields"] then
      for _, field in ipairs(options["search_fields"]) do
        local value, _, gsub_err = ngx.re.gsub(self.params["search"]["value"], "[%_\\\\]", "\\$0", "jo")
        if gsub_err then
          ngx.log(ngx.ERR, "regex error: ", gsub_err)
        end

        table.insert(search_sql, db.interpolate_query(db.escape_identifier(field) .. "::text ILIKE '%' || ? || '%'", value))
      end
    end
    table.insert(query["where"], "(" .. table.concat(search_sql, " OR ") .. ")")
  end

  local where = ""
  if not is_empty(options["joins"]) then
    where = table.concat(options["joins"], " ") .. " " .. where
  end

  if not is_empty(query["where"]) then
    where = where .. " WHERE (" .. table.concat(query["where"], ") AND (") .. ")"
  end
  -- local total_count = model:count(where)
  local total_count = model:select(where, { fields = "COUNT(*) AS c", load = false })["c"]

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

  if not is_empty(query["order"]) then
    where = where .. " ORDER BY " .. table.concat(query["order"], ", ")
  end

  if not is_empty(query["clause"]) then
    where = where .. " " .. table.concat(query["clause"], " ")
  end

  local response = {
    draw = tonumber(self.params["draw"]) or 0,
    recordsTotal = total_count,
    recordsFiltered = total_count,
    data = {},
  }

  local records = model:select(where)
  if options and options["preload"] then
    model:preload_relations(records, unpack(options["preload"]))
  end

  for _, record in ipairs(records) do
    table.insert(response["data"], record:as_json())
  end
  setmetatable(response["data"], cjson.empty_array_mt)

  return lapis_json(self, response)
end

return _M
