local cjson = require "cjson"
local db = require "lapis.db"
local escape_db_like = require "api-umbrella.utils.escape_db_like"
local int64_to_json_number = require("api-umbrella.utils.int64").to_json_number
local json_response = require "api-umbrella.web-app.utils.json_response"
local tablex = require "pl.tablex"
local types = require "pl.types"

local is_empty = types.is_empty
local table_keys = tablex.keys

local _M = {}

local function build_search_where(escaped_table_name, search_fields, search_value)
  local where = {}

  -- Always search on the "id" field, but only for exact matches.
  local uuid_matches, uuid_match_err = ngx.re.match(search_value, [[^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$]], "ijo")
  if uuid_matches then
    table.insert(where, db.interpolate_query(escaped_table_name .. ".id = ?", string.lower(search_value)))
  elseif uuid_match_err then
    ngx.log(ngx.ERR, "regex error: ", uuid_match_err)
  end

  -- Perform wildcard, case-insensitive searches on all the other fields.
  if search_fields then
    for _, field in ipairs(search_fields) do
      local field_name = field
      local field_search_value = search_value
      local prefix_search = false
      if type(field) == "table" and field["name"] then
        field_name = field["name"]

        if field["prefix_length"] then
          prefix_search = true
          field_search_value = string.sub(search_value, 1, field["prefix_length"])
        end
      end

      if prefix_search then
        table.insert(where, db.interpolate_query(db.escape_identifier(field_name) .. "::text ILIKE ? || '%'", escape_db_like(field_search_value)))
      else
        table.insert(where, db.interpolate_query(db.escape_identifier(field_name) .. "::text ILIKE '%' || ? || '%'", escape_db_like(field_search_value)))
      end
    end
  end

  return "(" .. table.concat(where, " OR ") .. ")"
end

local function build_order(self)
  local orders = {}
  local order_fields = _M.parse_order(self)
  for _, order_field in ipairs(order_fields) do
    local column_name = order_field[1]
    local dir = order_field[2]
    table.insert(orders, db.escape_identifier(column_name) .. " " .. dir)
  end

  return table.concat(orders, ", ")
end

local function build_sql_joins(joins)
  if not is_empty(joins) then
    return table.concat(joins, " ")
  else
    return ""
  end
end

local function build_sql_where(where)
  if not is_empty(where) then
    return " WHERE (" .. table.concat(where, ") AND (") .. ")"
  else
    return ""
  end
end

local function build_sql_order_by(order)
  if not is_empty(order) then
    return " ORDER BY " .. table.concat(order, ", ")
  else
    return ""
  end
end

local function build_sql_limit(limit)
  if not is_empty(limit) then
    return db.interpolate_query(" LIMIT ?", tonumber(limit))
  else
    return ""
  end
end

local function build_sql_offset(offset)
  if not is_empty(offset) then
    return db.interpolate_query(" OFFSET ?", tonumber(offset))
  else
    return ""
  end
end

function _M.parse_order(self)
  local order_fields = {}
  local orders = self.params["order"]
  local columns = self.params["columns"]

  if is_empty(orders) then
    return order_fields
  end

  -- Extract the numbered indexes from the "order[i][column]" data so we can
  -- loop over the indexes in sorted order.
  local order_indexes = {}
  for _, order_index in ipairs(table_keys(orders)) do
    table.insert(order_indexes, tonumber(order_index))
  end
  table.sort(order_indexes)

  -- Loop over the order data according do the column index ordering (so when
  -- sorting by multiple columns, which column to order by 1st, 2nd, etc).
  for _, order_index in ipairs(order_indexes) do
    local order = orders[tostring(order_index)]

    -- Extract the column column name from the separate columns data.
    local column_name
    local column_index = order["column"]
    if columns then
      local column = columns[column_index]
      if column then
        column_name = column["data"]
      end
    end

    -- Sort direction.
    local dir
    if order["dir"] and string.lower(order["dir"]) == "desc" then
      dir = "DESC"
    else
      dir = "ASC"
    end

    if column_name and dir then
      table.insert(order_fields, { column_name, dir })
    end
  end

  return order_fields
end

function _M.index(self, model, options)
  local sql = ""
  local query = {
    where = {},
    order = {},
  }

  local table_name = model:table_name()
  local escaped_table_name = db.escape_identifier(table_name)

  -- Static query filters
  if options["where"] then
    for _, where in ipairs(options["where"]) do
      table.insert(query["where"], where)
    end
  end

  -- Search filters
  if self.params["search"] and not is_empty(self.params["search"]["value"]) then
    table.insert(query["where"], build_search_where(escaped_table_name, options["search_fields"], self.params["search"]["value"]))
    sql = sql .. build_sql_joins(options["search_joins"])
  end

  -- Total count before applying limits.
  sql = sql .. build_sql_where(query["where"])
  local total_count = model:select(sql, { fields = "COUNT(*) AS c", load = false })[1]["c"]

  -- Order
  if not is_empty(self.params["order"]) then
    table.insert(query["order"], build_order(self))
  end

  -- Limit
  if not is_empty(self.params["length"]) then
    query["limit"] = self.params["length"]
  end

  -- Offset
  if not is_empty(self.params["start"]) then
    query["offset"] = self.params["start"]
  end

  sql = sql .. build_sql_order_by(query["order"])
  sql = sql .. build_sql_limit(query["limit"])
  sql = sql .. build_sql_offset(query["offset"])

  local response = {
    draw = tonumber(self.params["draw"]) or 0,
    recordsTotal = int64_to_json_number(total_count),
    recordsFiltered = int64_to_json_number(total_count),
    data = {},
  }

  local records = model:select(sql, {
    fields = "DISTINCT " .. escaped_table_name .. ".*",
  })
  if options and options["preload"] then
    model:preload_relations(records, unpack(options["preload"]))
  end

  for _, record in ipairs(records) do
    table.insert(response["data"], record:as_json())
  end
  setmetatable(response["data"], cjson.empty_array_mt)

  return json_response(self, response)
end

return _M
