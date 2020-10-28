local Model = require("lapis.db.model").Model
local capture_errors = require("lapis.application").capture_errors
local db = require "lapis.db"
local is_array = require "api-umbrella.utils.is_array"
local is_empty = require "api-umbrella.utils.is_empty"
local is_hash = require "api-umbrella.utils.is_hash"
local readonly = require("pl.tablex").readonly
local relations_loaded_key = require("lapis.db.model.relations").LOADED_KEY
local singularize = require("lapis.util").singularize
local t = require("api-umbrella.web-app.utils.gettext").gettext
local uuid_generate = require("resty.uuid").generate_random
local xpcall_error_handler = require "api-umbrella.utils.xpcall_error_handler"

local db_null = db.NULL

require "resty.validation.ngx"

local _M = {}

local function values_for_table(model_class, values)
  local column_values = {}
  for _, column in ipairs(model_class:columns()) do
    local name = column["column_name"]
    if values[name] ~= nil then
      column_values[name] = values[name]
    end
  end

  return column_values
end

local function merge_record_and_values(self, values)
  local merged = {}

  -- If a current record exists (during updates), then first fetch all of its
  -- values to provide the base, default values.
  if self then
    for key, value in pairs(self:attributes()) do
      merged[key] = value
    end
  end

  -- Override the defaults with the values currently being set.
  for key, value in pairs(values) do
    merged[key] = value
  end

  -- Return the table as readonly, so this doesn't get confused with the
  -- "values" table, where modifications are allowed (but since this combined
  -- table won't be used outside of validations, any updates made to it would
  -- be ignored).
  return readonly(merged)
end

function _M.start_transaction()
  -- Only open a new transaction if one isn't already opened.
  --
  -- When dealing with saving nested relationships, this ensures that only the
  -- parent model opens the transaction, and all associated child records are
  -- saved as part of that single transaction (assuming these child records are
  -- saved in the "after_save" callback, which still lives inside the parent's
  -- transaction). This ensures that the parent record save will only be
  -- committed if all child records also save successfully.
  local started = false
  if not ngx.ctx.model_transaction_started then
    db.query("START TRANSACTION")
    started = true
    ngx.ctx.model_transaction_started = true

    if ngx.ctx.current_admin then
      db.query("SET LOCAL audit.application_user_id = ?", ngx.ctx.current_admin.id)
      db.query("SET LOCAL audit.application_user_name = ?", ngx.ctx.current_admin.username)
    else
      -- TODO: What to do for stamping for non admins (api key signup)?
      db.query("SET LOCAL audit.application_user_id = ?", "00000000-0000-0000-0000-000000000000")
      db.query("SET LOCAL audit.application_user_name = ?", "admin")
    end
  end

  return started
end

function _M.commit_transaction(started)
  -- Only commit the transaction if the current record started the transaction
  -- (see start_transaction).
  if started then
    db.query("COMMIT")
    ngx.ctx.model_transaction_started = false
  end
end

function _M.rollback_transaction(started)
  ngx.ctx.validate_error_field_prefix = nil

  -- Only rollback the transaction if the current record started the
  -- transaction (see start_transaction).
  if started then
    db.query("ROLLBACK")
    ngx.ctx.model_transaction_started = false
  end
end

local function before_save(self, action, callbacks, values)
  if action == "create" then
    if not values["id"] or values["id"] == db_null then
      values["id"] = uuid_generate()
    end

    if callbacks["before_validate_on_create"] then
      callbacks["before_validate_on_create"](self, values)
    end
  end

  if callbacks["before_validate"] then
    callbacks["before_validate"](self, values)
  end

  -- The "values" object only contains values currently being set as part of
  -- the current request. But for partial updates, this may not include the
  -- existing data that isn't being updated. For validation purposes, we're
  -- usually interested in the combined view, so merge the values on top of the
  -- existing record.
  local data = merge_record_and_values(self, values)

  -- Authorize that on create or on updates, the current user is authorized to
  -- the resulting record.
  --
  -- On updates, this is actually the second authorization call we make. We
  -- authorize once before making any updates, and again here with the
  -- potential updates taken into account. This ensures a user can't take a
  -- record they're authorized to and update it to something outside their
  -- permissions.
  if callbacks["authorize"] then
    callbacks["authorize"](data, action)
  end

  if callbacks["validate"] then
    local errors = callbacks["validate"](self, data, values)
    if not is_empty(errors) then
      return coroutine.yield("error", errors)
    end
  end

  if callbacks["after_validate"] then
    callbacks["after_validate"](self, values)
  end

  if callbacks["before_save"] then
    callbacks["before_save"](self, values)
  end
end

local function after_save(self, _, callbacks, values)
  if callbacks["after_save"] then
    callbacks["after_save"](self, values)
  end
end

local function after_commit(self, _, callbacks, values)
  -- After making changes, refresh the record to read in changes that may have
  -- taken place in the database layer. This accounts for default values set by
  -- the database or values set by triggers (like updated_at/updated_by).
  --
  -- While doing a separate SELECT statement to refresh the record isn't the
  -- most efficient (a better approach would be to account for all the fields
  -- in the RETURNING clause of the INSERT/UPDATE), this is the simplest way to
  -- ensure we get all the potential changes from the database.
  self:refresh()

  if callbacks["after_commit"] then
    callbacks["after_commit"](self, values)
  end
end

function _M.try_save(fn, transaction_started)
  local save = capture_errors({
    -- Handle Lapis validation errors (since these are handled via coroutine
    -- yielding). Be sure to abort the transaction (so it's not left open), and
    -- re-raise the error.
    on_error = function(err)
      _M.rollback_transaction(transaction_started)
      return coroutine.yield("error", err.errors)
    end,
    fn,
  })

  -- Handle lower-level Lua errors by wrapping things in pcall. This ensures we
  -- can also abort the transaction in the event of these lower-level errors.
  local ok, err = xpcall(save, xpcall_error_handler, {})
  if not ok then
    _M.rollback_transaction(transaction_started)
    error(err)
  end
end

function _M.record_attributes(self, options)
  local includes = {}
  if options and options["includes"] then
    includes = options["includes"]
  end

  local attributes = {}

  -- Fetch values from the record directly.
  for key, value in pairs(self) do
    attributes[key] = value
  end

  -- Fetch the values from relations on the record.
  for relation_name, relation_options in pairs(includes) do
    local singular_relation_name = singularize(relation_name)
    local records = self["get_" .. relation_name](self)
    if is_array(records) then
      attributes[relation_name] = {}
      attributes[singular_relation_name .. "_ids"] = {}
      for _, record in ipairs(records) do
        local record_attrs = record:attributes(relation_options)
        table.insert(attributes[relation_name], record_attrs)
        table.insert(attributes[singular_relation_name .. "_ids"], record_attrs["id"])
      end
    elseif records then
      local record_attrs = records:attributes(relation_options)
      attributes[relation_name] = record_attrs
      attributes[singular_relation_name .. "_id"] = record_attrs["id"]
    end
  end

  -- Unset the special key indicating that the relations are loaded, since it's
  -- not relevant for this attributes-only table of data.
  attributes[relations_loaded_key] = nil

  return readonly(attributes)
end

function _M.add_error(errors, field, field_label, message)
  assert(errors)
  assert(field)
  assert(field_label)
  assert(message)

  table.insert(errors, {
    code = "INVALID_INPUT",
    field = field,
    field_label = field_label,
    message = message,
  })
end

function _M.validate_field(errors, values, field, field_label, validators, options)
  assert(errors)
  assert(values)
  assert(field)
  assert(field_label)
  assert(validators)

  local value = values[field]
  for _, validator_data in ipairs(validators) do
    local validator = assert(validator_data[1])
    local message = assert(validator_data[2])

    local ok = validator(value)
    if not ok then
      local error_field = field
      if options then
        if options["error_field"] then
          error_field = options["error_field"]
        end

        if options["error_field_prefix"] then
          error_field = options["error_field_prefix"] .. error_field
        end
      end

      if ngx.ctx.validate_error_field_prefix then
        error_field = ngx.ctx.validate_error_field_prefix .. error_field
      end

      _M.add_error(errors, error_field, field_label, message)
    end
  end
end

function _M.validate_uniqueness(errors, values, error_field, field_label, model, unique_fields)
  assert(values["id"])
  assert(type(unique_fields) == "table")
  assert(#unique_fields > 0)
  local table_name = assert(model:table_name())

  local conditions = {}
  table.insert(conditions, "id != " .. db.escape_literal(values["id"]))

  for _, unique_field in ipairs(unique_fields) do
    if not values[unique_field] or values[unique_field] == db_null then
      return nil
    end

    table.insert(conditions, db.escape_identifier(unique_field) .. " = " .. db.escape_literal(values[unique_field]))
  end

  local where = table.concat(conditions, " AND ")

  -- Use a raw query, rather than model:count, since Lapis' models don't
  -- properly handle manually escaped SQL queries that might contain question
  -- marks in strings (it thinks any "?" needs to be interpolated).
  local result = db.select("COUNT(*) AS c FROM " .. db.escape_identifier(table_name) .. " WHERE " .. where)
  local count = result[1]["c"]
  if count > 0 then
    _M.add_error(errors, error_field, field_label, t("is already taken"))
  end
end

function _M.validate_relation_uniqueness(errors, values, relation_name, error_field, field_label, unique_fields)
  if not values[relation_name] or values[relation_name] == db_null then
    return
  end

  assert(type(values[relation_name]) == "table")
  assert(type(unique_fields) == "table")
  assert(#unique_fields > 0)

  local seen = {}
  for index, relation_record in ipairs(values[relation_name]) do
    local key = {}
    for _, unique_field in ipairs(unique_fields) do
      local value = relation_record[unique_field]
      if value == db_null then
        value = "db_null"
      end
      table.insert(key, tostring(value))
    end

    key = table.concat(key, ":")

    if seen[key] then
      _M.add_error(errors, relation_name .. "[" .. (index - 1) .. "]." .. error_field, field_label, t("is already taken"))
    end

    seen[key] = true
  end
end

local function create(callbacks)
  return function(model_class, values, opts)
    local transaction_started = _M.start_transaction()

    local new_record
    _M.try_save(function()
      before_save(nil, "create", callbacks, values)
      new_record = Model.create(model_class, values_for_table(model_class, values), opts)
      after_save(new_record, "create", callbacks, values)
    end, transaction_started)

    _M.commit_transaction(transaction_started)
    after_commit(new_record, "create", callbacks, values)

    return new_record
  end
end

local function update(callbacks)
  return function(self, values, opts)
    -- Before starting the update, ensure the current user is authorized to
    -- this record.
    callbacks["authorize"](self:attributes())

    local model_class = self.__class
    local transaction_started = _M.start_transaction()

    local return_value
    _M.try_save(function()
      before_save(self, "update", callbacks, values)
      return_value = Model.update(self, values_for_table(model_class, values), opts)
      after_save(self, "update", callbacks, values)
    end, transaction_started)

    _M.commit_transaction(transaction_started)
    after_commit(self, "update", callbacks, values)

    return return_value
  end
end

local function delete(callbacks)
  return function(self)
    -- Before starting the update, ensure the current user is authorized to
    -- this record.
    callbacks["authorize"](self:attributes())

    local transaction_started = _M.start_transaction()

    local return_value
    _M.try_save(function()
      return_value = Model.delete(self)
    end, transaction_started)

    _M.commit_transaction(transaction_started)

    return return_value
  end
end

local function get_join_records(model_name, options, ids, include_foreign_key_id)
  local model = Model:get_relation_model(model_name)
  local join_table = db.escape_identifier(options["join_table"])
  local table_name = db.escape_identifier(model:table_name())
  local primary_key = db.escape_identifier(model.primary_key)
  local foreign_key = db.escape_identifier(options["foreign_key"])
  local association_foreign_key = db.escape_identifier(options["association_foreign_key"])
  local order_by = ""
  if options["order"] then
    order_by = " ORDER BY " .. table_name .. "." .. db.escape_identifier(options["order"])
  end

  local sql = "INNER JOIN " .. join_table .. " ON " .. table_name .. "." .. primary_key .. " = " .. join_table .. "." .. association_foreign_key ..
    " WHERE " .. join_table .. "." .. foreign_key .. " IN ?" ..
    order_by

  local fields = table_name .. ".*"
  if include_foreign_key_id then
    fields = fields .. ", " .. join_table .. "." .. foreign_key .. " AS _foreign_key_id"
  end

  return model:select(sql, db.list(ids), { fields = fields })
end

function _M.has_and_belongs_to_many(name, model_name, options)
  return {
    name,
    fetch = function(self)
      return get_join_records(model_name, options, { self.id })
    end,
    preload = function(primary_records)
      local primary_record_ids = {}
      for _, primary_record in ipairs(primary_records) do
        primary_record[name] = {}
        table.insert(primary_record_ids, primary_record.id)
      end

      if #primary_record_ids > 0 then
        local join_records = get_join_records(model_name, options, primary_record_ids, true)
        for _, join_record in ipairs(join_records) do
          for _, primary_record in ipairs(primary_records) do
            if primary_record.id == join_record["_foreign_key_id"] then
              join_record["_foreign_key_id"] = nil
              table.insert(primary_record[name], join_record)
            end
          end
        end
      end
    end,
  }
end

function _M.save_has_and_belongs_to_many(self, association_foreign_key_ids, options)
  if association_foreign_key_ids then
    local join_table = db.escape_identifier(options["join_table"])
    local foreign_key = db.escape_identifier(options["foreign_key"])
    local association_foreign_key = db.escape_identifier(options["association_foreign_key"])

    if not is_empty(association_foreign_key_ids) and association_foreign_key_ids ~= db_null then
      for _, association_foreign_key_id in ipairs(association_foreign_key_ids) do
        db.query("INSERT INTO " .. join_table .. "(" .. foreign_key .. ", " .. association_foreign_key .. ") VALUES(?, ?) ON CONFLICT DO NOTHING", self.id, association_foreign_key_id)
      end

      db.query("DELETE FROM " .. join_table .. " WHERE " .. foreign_key .. " = ? AND " .. association_foreign_key .. " NOT IN ?", self.id, db.list(association_foreign_key_ids))
    else
      db.query("DELETE FROM " .. join_table .. " WHERE " .. foreign_key .. " = ?", self.id)
    end
  end
end

function _M.has_many_update_or_create(self, relation_model, foreign_key, relation_values)
  assert(foreign_key)
  relation_values[foreign_key] = assert(self.id)

  local relation_record
  if relation_values["id"] then
    relation_record = relation_model:find({
      [foreign_key] = relation_values[foreign_key],
      id = relation_values["id"],
    })
  end

  if relation_record then
    assert(relation_record:update(relation_values))
  else
    relation_record = assert(relation_model:create(relation_values))
  end

  return relation_record
end

function _M.has_many_delete_except(self, relation_model, foreign_key, keep_ids, conditions)
  assert(foreign_key)
  local table_name = assert(relation_model:table_name())
  local parent_id = assert(self.id)

  local where = db.escape_identifier(foreign_key) .. " = " .. db.escape_literal(parent_id)
  if conditions then
    where = where .. " AND " .. conditions
  end

  if not is_empty(keep_ids) then
    where = where .. " AND id NOT IN " .. db.escape_literal(db.list(keep_ids))
  end

  -- Use a raw query, rather than model:delete, since Lapis' models don't
  -- properly handle manually escaped SQL queries that might contain question
  -- marks in strings (it thinks any "?" needs to be interpolated).
  db.query("DELETE FROM " .. db.escape_identifier(table_name) .. " WHERE " .. where)
end

function _M.has_many_save(self, values, name)
  local relations_values = values[name]
  if relations_values == db_null then
    self[name .. "_delete_except"](self, {})
  elseif is_array(relations_values) then
    -- First determine which child records exist and will be kept.
    local keep_ids = {}
    for _, relation_values in ipairs(relations_values) do
      if not relation_values["id"] or relation_values["id"] == db_null then
        relation_values["id"] = uuid_generate()
      end
      table.insert(keep_ids, assert(relation_values["id"]))
    end

    -- Next, delete any child records that won't be retained during this save.
    --
    -- We must do this before the subsequent create/updates so that any
    -- uniqueness validations in those child record validations take into
    -- account removed records. Since this is all wrapped in a transaction,
    -- it's safe to go ahead and delete these.
    self[name .. "_delete_except"](self, keep_ids)

    -- Finally, create or update any child records based on the current values.
    for index, relation_values in ipairs(relations_values) do
      ngx.ctx.validate_error_field_prefix = name .. "[" .. (index - 1) .. "]."
      self[name .. "_update_or_create"](self, relation_values)
      ngx.ctx.validate_error_field_prefix = nil
    end
  end
end

function _M.has_one_update_or_create(self, relation_model, foreign_key, relation_values)
  assert(foreign_key)
  relation_values[foreign_key] = assert(self.id)

  local relation_record = relation_model:find({
    [foreign_key] = relation_values[foreign_key],
  })

  if relation_record then
    assert(relation_record:update(relation_values))
  else
    relation_record = assert(relation_model:create(relation_values))
  end

  return relation_record
end

function _M.has_one_delete(self, relation_model, foreign_key, conditions)
  return _M.has_many_delete_except(self, relation_model, foreign_key, {}, conditions)
end

function _M.has_one_save(self, values, name)
  local relation_values = values[name]
  if relation_values == db_null then
    self[name .. "_delete"](self)
  elseif is_hash(relation_values) then
    self[name .. "_update_or_create"](self, relation_values)
  end
end

function _M.new_class(table_name, model_options, callbacks)
  model_options.update = update(callbacks)
  model_options.delete = delete(callbacks)
  if not model_options.attributes then
    model_options.attributes = _M.record_attributes
  end

  -- Our overwritten create/update always perform authorization callbacks, but
  -- alias these functions to more explicitly named "authorized" versions. This
  -- is just to make the intent clearer when calling (but we'll still leave the
  -- original create/update functions overridden, so we can ensure any default
  -- create/updates also get authorized).
  model_options.authorized_update = model_options.update
  model_options.authorized_delete = model_options.delete

  local model_class = Model:extend(table_name, model_options)
  model_class.create = create(callbacks)
  model_class.authorized_create = model_class.create

  return model_class
end

function _M.transaction_update(table_name, values, cond, ...)
  local transaction_started = _M.start_transaction()
  db.update(table_name, values, cond, ...)
  _M.commit_transaction(transaction_started)
end

return _M
