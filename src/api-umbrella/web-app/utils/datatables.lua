local cjson = require "cjson"
local common_validations = require "api-umbrella.web-app.utils.common_validations"
local csv = require "api-umbrella.web-app.utils.csv"
local db = require "lapis.db"
local escape_db_like = require "api-umbrella.utils.escape_db_like"
local int64_to_json_number = require("api-umbrella.utils.int64").to_json_number
local is_empty = require "api-umbrella.utils.is_empty"
local json_response = require "api-umbrella.web-app.utils.json_response"
local model_ext = require "api-umbrella.web-app.utils.model_ext"
local pg_utils = require "api-umbrella.utils.pg_utils"
local preload = require("lapis.db.model").preload
local split = require("ngx.re").split
local t = require("api-umbrella.web-app.utils.gettext").gettext
local table_keys = require("pl.tablex").keys
local validation_ext = require "api-umbrella.web-app.utils.validation_ext"

local add_error = model_ext.add_error
local re_find = ngx.re.find
local validate_field = model_ext.validate_field

local _M = {}

local function build_search_where(escaped_table_name, search_fields, search_value)
  local where = {}

  -- Always search on the "id" field, but only for exact matches.
  local uuid_find_from, _, uuid_find_err = re_find(search_value, common_validations.uuid, "ijo")
  if uuid_find_from then
    table.insert(where, db.interpolate_query(escaped_table_name .. ".id = ?", string.lower(search_value)))
  elseif uuid_find_err then
    ngx.log(ngx.ERR, "regex error: ", uuid_find_err)
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

local function build_order(self, options)
  local orders = {}
  local order_selects = {}
  local order_joins = {}
  local order_fields = _M.parse_order(self)
  for _, order_field in ipairs(order_fields) do
    local column_name = order_field[1]
    local dir = order_field[2]
    if not is_empty(column_name) and not is_empty(dir) then
      local parts = split(column_name, "\\.", "jo", nil, 2)
      local quoted_parts = { db.escape_identifier(parts[1]) }
      if parts[2] then
        table.insert(quoted_parts, db.escape_identifier(parts[2]))
      end
      local quoted_column = table.concat(quoted_parts, ".")

      table.insert(orders, quoted_column .. " " .. dir)

      if parts[2] then
        table.insert(order_selects, quoted_column)
      end

      if options["order_joins"] and options["order_joins"][column_name] then
        table.insert(order_joins, options["order_joins"][column_name])
      end
    end
  end

  return orders, order_selects, order_joins
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

local function validate(values, options)
  local errors = {}
  validate_field(errors, values, "length", "length", {
    { validation_ext.optional.tonumber.number, t("is not a number") },
  })
  validate_field(errors, values, "start", "start", {
    { validation_ext.optional.tonumber.number, t("is not a number") },
  })
  validate_field(errors, values, "draw", "draw", {
    { validation_ext.optional.tonumber.number, t("is not a number") },
  })
  validate_field(errors, values, "columns", "columns", {
    { validation_ext.optional.table, t("is not an object") },
  })
  validate_field(errors, values, "order", "order", {
    { validation_ext.optional.table, t("is not an object") },
  })
  local column_indexes = {}
  if not is_empty(values["columns"]) and type(values["columns"]) == "table" then
    for index, _ in pairs(values["columns"]) do
      local ok = validation_ext.tonumber.number(index)
      if not ok then
        add_error(errors, "columns", "columns[" .. index .. "]", t("is not a number"))
      else
        table.insert(column_indexes, tonumber(index))
      end
    end
  end
  if not is_empty(values["order"]) and type(values["order"]) == "table" then
    for index, order in pairs(values["order"]) do
      local ok = validation_ext.tonumber.number(index)
      if not ok then
        add_error(errors, "columns", "columns[" .. index .. "]", t("is not a number"))
      else
        validate_field(errors, order, "column", "order[" .. index .. "][column]", {
          { validation_ext.optional.tonumber.number, t("is not a number") },
          { validation_ext.optional.tonumber:oneof(unpack(column_indexes)), t("is not a valid column index") },
        })
        validate_field(errors, order, "dir", "order[" .. index .. "][dir]", {
          { validation_ext.optional:oneof("asc", "desc"), t("must be 'asc' or 'desc'") },
        })

        local column_index = tonumber(order["column"])
        if column_index then
          validate_field(errors, values["columns"][column_index] or values["columns"][tostring(column_index)] or {}, "data", "columns[" .. column_index .. "][data]", {
            { validation_ext:oneof(unpack(options["order_fields"] or {})), t("is not a valid orderable column name") },
          })
        end
      end
    end
  end
  return errors
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
  local errors = validate(self.params, options)
  if not is_empty(errors) then
    return coroutine.yield("error", errors)
  end

  local sql = ""
  local query = {
    where = {},
  }

  local table_name = model:table_name()
  local escaped_table_name = db.escape_identifier(table_name)
  local joins_present = false

  -- Static query filters
  if options["where"] then
    for _, where in ipairs(options["where"]) do
      table.insert(query["where"], where)
    end
  end

  -- Search filters
  if self.params["search"] and not is_empty(self.params["search"]["value"]) then
    table.insert(query["where"], build_search_where(escaped_table_name, options["search_fields"], self.params["search"]["value"]))
    if not is_empty(options["search_joins"]) then
      joins_present = true
      sql = sql .. build_sql_joins(options["search_joins"])
    end
  end

  -- Order
  local order_selects
  local order_joins
  if not is_empty(self.params["order"]) then
    query["order"], order_selects, order_joins = build_order(self, options)
  end

  if not is_empty(order_joins) then
    joins_present = true
    sql = sql .. build_sql_joins(order_joins)
  end

  local distinct_sql = ""
  if joins_present then
    distinct_sql = "DISTINCT "
  end

  -- Total count before applying limits.
  sql = sql .. build_sql_where(query["where"])
  local total_count = model:select(sql, { fields = "COUNT(" .. distinct_sql .. escaped_table_name .. ".id) AS c", load = false })[1]["c"]

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

  local fields = distinct_sql .. escaped_table_name .. ".*"
  if not is_empty(order_selects) then
    fields = fields .. ", " .. table.concat(order_selects, ", ")
  end

  if self.params["format"] == "csv" then
    csv.set_response_headers(self, options["csv_filename"] .. "_" .. os.date("!%Y-%m-%d", ngx.now()) .. ".csv")
    ngx.say(csv.row_to_csv(model:csv_headers()))
    ngx.flush(true)
  end

  local select_sql = "SELECT " .. fields .. " FROM " .. escaped_table_name .. " " .. sql
  local _, cursor_err = pg_utils.cursor(select_sql, nil, 1000, { fatal = true }, function(results)
    local records = model:load_all(results)

    if options and options["preload"] then
      preload(records, options["preload"])
    end

    for _, record in ipairs(records) do
      if self.params["format"] == "csv" then
        ngx.say(csv.row_to_csv(record:as_csv()))
      else
        table.insert(response["data"], record:as_json())
      end
    end

    if self.params["format"] == "csv" then
      ngx.flush(true)
    end
  end)
  if cursor_err then
    error("cursor error: " .. cursor_err)
  end

  if self.params["format"] == "csv" then
    return { layout = false }
  else
    setmetatable(response["data"], cjson.empty_array_mt)
    return json_response(self, response)
  end
end

return _M
