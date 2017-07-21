local Model = require("lapis.db.model").Model
local _ = require("resty.gettext").gettext
local cjson = require "cjson"
local bcrypt = require "bcrypt"
local db = require "lapis.db"
local iso8601 = require "api-umbrella.utils.iso8601"
local model_ext = require "api-umbrella.utils.model_ext"
local random_token = require "api-umbrella.utils.random_token"
local validation = require "resty.validation"
local types = require "pl.types"

local is_empty = types.is_empty
local db_null = db.NULL
local json_null = cjson.null
local validate_field = model_ext.validate_field

local function before_validate_on_create(self, values)
  local authentication_token = random_token(40)
  values["authentication_token_hash"] = authentication_token
  values["authentication_token_encrypted"] = authentication_token
end

local function validate(self, values)
  local errors = {}
  validate_field(errors, values, "username", validation.string:minlen(1), _("can't be blank"))

  if values["superuser"] == db_null then
    values["superuser"] = false
  end
  if not values["superuser"] then
    validate_field(errors, values, "group_ids", validation.table:minlen(1), _("must belong to at least one group or be a superuser"))
  end

  if not is_empty(values["password"]) or not is_empty(values["password_confirmation"]) then
    validate_field(errors, values, "password", validation.string:minlen(1), _("can't be blank"))
    validate_field(errors, values, "password_confirmation", validation.string:minlen(1), _("can't be blank"))
    validate_field(errors, values, "password", validation.string:equals(values["password_confirmation"]), _("doesn't match password"))

    if self and self.id then
      validate_field(errors, values, "current_password", validation.string:minlen(1), _("can't be blank"))
      if not is_empty(values["current_password"]) then
        if not self:is_valid_password(values["current_password"]) then
          model_ext.add_error(errors, "current_password", _("is invalid"))
        end
      end
    end
  end

  return errors
end

local function after_validate(self, values)
  if not is_empty(values["password"]) then
    values["password_hash"] = bcrypt.digest(values["password"], 11)
  end
end

local function after_save(self, values)
  model_ext.save_has_and_belongs_to_many(self, values["group_ids"], {
    join_table = "admin_groups_admins",
    foreign_key = "admin_id",
    association_foreign_key = "admin_group_id",
  })
end

local save_options = {
  before_validate_on_create = before_validate_on_create,
  validate = validate,
  after_validate = after_validate,
  after_save = after_save,
}

local Admin = Model:extend("admins", {
  relations = {
    model_ext.has_and_belongs_to_many("groups", "AdminGroup", {
      join_table = "admin_groups_admins",
      foreign_key = "admin_id",
      association_foreign_key = "admin_group_id",
      order = "name",
    }),
  },

  update = model_ext.update(save_options),

  is_valid_password = function(self, password)
    if self.password_hash and password and bcrypt.verify(password, self.password_hash) then
      return true
    else
      return false
    end
  end,

  is_access_locked = function(self)
    if self.locked_at and not self:is_lock_expired() then
      return true
    else
      return false
    end
  end,

  is_lock_expired = function(self)
    if self.locked_at and self.locked_at < 0 then -- TODO
      return true
    else
      return false
    end
  end,

  authentication_token_decrypted = function(self)
    return self.authentication_token_encrypted
  end,

  group_ids = function(self)
    local group_ids = {}
    local groups = self:get_groups()
    for _, group in ipairs(groups) do
      table.insert(group_ids, group.id)
    end

    return group_ids
  end,

  group_names = function(self)
    local group_names = {}
    for _, group in ipairs(self:get_groups()) do
      table.insert(group_names, group.name)
    end
    if self.superuser then
      table.insert(group_names, _("Superuser"))
    end

    return group_names
  end,

  as_json = function(self)
    local data = {
      id = self.id or json_null,
      username = self.username or json_null,
      email = self.email or json_null,
      name = self.name or json_null,
      notes = self.notes or json_null,
      superuser = self.superuser or json_null,
      current_sign_in_provider = self.current_sign_in_provider or json_null,
      last_sign_in_provider = self.last_sign_in_provider or json_null,
      reset_password_sent_at = self.reset_password_sent_at or json_null,
      sign_in_count = self.sign_in_count or json_null,
      current_sign_in_at = self.current_sign_in_at or json_null,
      last_sign_in_at = self.last_sign_in_at or json_null,
      current_sign_in_ip = self.current_sign_in_ip or json_null,
      last_sign_in_ip = self.last_sign_in_ip or json_null,
      failed_attempts = self.failed_attempts or json_null,
      locked_at = self.locked_at or json_null,
      created_at = iso8601.format_postgres(self.created_at) or json_null,
      created_by = self.created_by or json_null,
      updated_at = iso8601.format_postgres(self.updated_at) or json_null,
      updated_by = self.updated_by or json_null,
      group_ids = self:group_ids() or json_null,
      group_names = self:group_names() or json_null,
      deleted_at = json_null,
      version = 1,
    }
    setmetatable(data["group_ids"], cjson.empty_array_mt)
    setmetatable(data["group_names"], cjson.empty_array_mt)
    return data
  end,
})

Admin.create = model_ext.create(save_options)

Admin.needs_first_account = function()
  local needs = false
  if config["web"]["admin"]["auth_strategies"]["_local_enabled?"] and Admin:count() == 0 then
    needs = true
  end

  return needs
end

return Admin
