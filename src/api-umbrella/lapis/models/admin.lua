local Model = require("lapis.db.model").Model
local bcrypt = require "bcrypt"
local cjson = require "cjson"
local db = require "lapis.db"
local db_null = require("lapis.db").NULL
local encryptor = require "api-umbrella.utils.encryptor"
local hmac = require "api-umbrella.utils.hmac"
local is_empty = require("pl.types").is_empty
local iso8601 = require "api-umbrella.utils.iso8601"
local model_ext = require "api-umbrella.utils.model_ext"
local random_token = require "api-umbrella.utils.random_token"
local t = require("resty.gettext").gettext
local validation = require "resty.validation"

local json_null = cjson.null
local validate_field = model_ext.validate_field

local function before_validate_on_create(_, values)
  ngx.log(ngx.ERR, "before_validate_on_create")
  local authentication_token = random_token(40)
  values["authentication_token_hash"] = hmac(authentication_token)
  local encrypted, iv = encryptor.encrypt(authentication_token, values["id"])
  values["authentication_token_encrypted"] = encrypted
  values["authentication_token_encrypted_iv"] = iv
end

local function before_validate(_, values)
  ngx.log(ngx.ERR, "before_validate" .. inspect(values))
  if config["web"]["admin"]["username_is_email"] then
    values["email"] = values["username"]
  end
end

local function validate_email(_, values, errors)
  validate_field(errors, values, "username", validation.string:minlen(1), t("can't be blank"))
  if config["web"]["admin"]["username_is_email"] then
    if not is_empty(values["username"]) then
      validate_field(errors, values, "username", validation:regex(config["web"]["admin"]["email_regex"], "jo"), t("is invalid"))
    end
  else
    if not is_empty(values["email"]) then
      validate_field(errors, values, "email", validation:regex(config["web"]["admin"]["email_regex"], "jo"), t("is invalid"))
    end
  end
end

local function validate_groups(_, values, errors)
  if values["superuser"] == db_null then
    values["superuser"] = false
  end
  if not values["superuser"] then
    validate_field(errors, values, "group_ids", validation.table:minlen(1), t("must belong to at least one group or be a superuser"))
  end
end

local function validate_password(self, values, errors)
  local is_password_required = false
  local auth_strategies = config["web"]["admin"]["auth_strategies"]["enabled"]
  if #auth_strategies == 1 and auth_strategies[1] == "local" then
    is_password_required = true
  elseif not is_empty(values["password"]) or not is_empty(values["password_confirmation"]) then
    is_password_required = true
  end

  if is_password_required then
    validate_field(errors, values, "password", validation.string:minlen(1), t("can't be blank"))
    validate_field(errors, values, "password_confirmation", validation.string:minlen(1), t("can't be blank"))
    validate_field(errors, values, "password_confirmation", validation.string:equals(values["password"]), t("doesn't match password"))

    if not is_empty(values["password"]) then
      local password_length_min = config["web"]["admin"]["password_length_min"]
      local password_length_max = config["web"]["admin"]["password_length_max"]
      validate_field(errors, values, "password", validation.string:minlen(password_length_min), string.format(t("is too short (minimum is %d characters)"), password_length_min))
      validate_field(errors, values, "password", validation.string:maxlen(password_length_max), string.format(t("is too long (maximum is %d characters)"), password_length_max))
    end

    if self and self.id then
      validate_field(errors, values, "current_password", validation.string:minlen(1), t("can't be blank"))
      if not is_empty(values["current_password"]) then
        if not self:is_valid_password(values["current_password"]) then
          model_ext.add_error(errors, "current_password", t("is invalid"))
        end
      end
    end
  end
end

local function validate(self, values)
  ngx.log(ngx.ERR, "validate")
  local errors = {}
  validate_email(self, values, errors)
  validate_groups(self, values, errors)
  validate_password(self, values, errors)

  return errors
end

local function after_validate(_, values)
  ngx.log(ngx.ERR, "after_validate")
  if not is_empty(values["password"]) then
    values["password_hash"] = bcrypt.digest(values["password"], 11)
  end
end

local function after_save(self, values)
  ngx.log(ngx.ERR, "after_save")
  model_ext.save_has_and_belongs_to_many(self, values["group_ids"], {
    join_table = "admin_groups_admins",
    foreign_key = "admin_id",
    association_foreign_key = "admin_group_id",
  })
end

local save_options = {
  before_validate_on_create = before_validate_on_create,
  before_validate = before_validate,
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
    local decrypted
    if self.authentication_token_encrypted and self.authentication_token_encrypted_iv then
      decrypted = encryptor.decrypt(self.authentication_token_encrypted, self.authentication_token_encrypted_iv, self.id)
    end

    return decrypted
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
      table.insert(group_names, t("Superuser"))
    end

    return group_names
  end,

  as_json = function(self, current_admin)
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
      authentication_token = json_null,
      deleted_at = json_null,
      version = 1,
    }
    setmetatable(data["group_ids"], cjson.empty_array_mt)
    setmetatable(data["group_names"], cjson.empty_array_mt)

    ngx.log(ngx.ERR, "CURRENT: " .. inspect(current_admin))
    if current_admin and current_admin.id == self.id then
      data["authentication_token"] = self:authentication_token_decrypted()
    end

    return data
  end,

  set_reset_password_token = function(self)
    local token = random_token(24)
    local token_hash = hmac(token)
    db.update("admins", {
      reset_password_token_hash = token_hash,
      reset_password_sent_at = db.raw("now() AT TIME ZONE 'UTC'"),
    }, { id = assert(self.id) })
    self:refresh()

    return token
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
