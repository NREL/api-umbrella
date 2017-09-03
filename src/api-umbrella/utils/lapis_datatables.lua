local cjson = require "cjson"
local db = require "lapis.db"
local escape_db_like = require "api-umbrella.utils.escape_db_like"
local lapis_json = require "api-umbrella.utils.lapis_json"
local tablex = require "pl.tablex"
local types = require "pl.types"

local is_empty = types.is_empty
local table_keys = tablex.keys

local _M = {}

local function parse_datatables_order(orders, columns)
  local sql_orders = {}

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
      table.insert(sql_orders, db.escape_identifier(column_name) .. " " .. dir)
    end
  end

  return table.concat(sql_orders, ", ")
end

local function build_search_where(escaped_table_name, search_fields, search_value)
  local where = {}

  -- Always search on the "id" field, but only for exact matches.
  table.insert(where, db.interpolate_query(escaped_table_name .. ".id::text = ?", string.lower(search_value)))

  -- Perform wildcard, case-insensitive searches on all the other fields.
  if search_fields then
    for _, field in ipairs(search_fields) do
      table.insert(where, db.interpolate_query(db.escape_identifier(field) .. "::text ILIKE '%' || ? || '%'", escape_db_like(search_value)))
    end
  end

  return "(" .. table.concat(where, " OR ") .. ")"
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
  if is_empty(self.params["order"]) then
    table.insert(query["order"], "name ASC")
  else
    table.insert(query["order"], parse_datatables_order(self.params["order"], self.params["columns"]))
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
    recordsTotal = total_count,
    recordsFiltered = total_count,
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

  return lapis_json(self, response)
end

return _M
