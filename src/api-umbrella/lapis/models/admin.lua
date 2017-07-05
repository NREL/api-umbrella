local Model = require("lapis.db.model").Model
local validation = require "resty.validation"
local iso8601 = require "api-umbrella.utils.iso8601"
local model_ext = require "api-umbrella.utils.model_ext"
local random_token = require "api-umbrella.utils.random_token"
local cjson = require "cjson"

local json_null = cjson.null
local validate_field = model_ext.validate_field

local function before_create(_, values)
  values["authentication_token"] = random_token(40)
end

local function validate(values)
  local errors = {}
  validate_field(errors, values, "username", validation.string:minlen(1), "can't be blank")
  return errors
end

local Admin = Model:extend("admins", {
  update = model_ext.update(validate),

  as_json = function(self)
    return {
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
      deleted_at = json_null,
      version = 1,
    }
  end,
})

Admin.create = model_ext.create({
  before_create = before_create,
  validate = validate,
})

return Admin
