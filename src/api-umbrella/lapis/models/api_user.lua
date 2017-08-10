local Model = require("lapis.db.model").Model
local encryptor = require "api-umbrella.utils.encryptor"
local hmac = require "api-umbrella.utils.hmac"
local iso8601 = require "api-umbrella.utils.iso8601"
local json_null = require("cjson").null
local model_ext = require "api-umbrella.utils.model_ext"
local random_token = require "api-umbrella.utils.random_token"
local t = require("resty.gettext").gettext
local validation = require "resty.validation"

local validate_field = model_ext.validate_field

local function before_validate_on_create(_, values)
  local api_key = random_token(40)
  values["api_key_hash"] = hmac(api_key)
  local encrypted, iv = encryptor.encrypt(api_key, values["id"])
  values["api_key_encrypted"] = encrypted
  values["api_key_encrypted_iv"] = iv
  values["api_key_prefix"] = string.sub(api_key, 1, 10)
end

local function validate(self, values)
  local errors = {}
  validate_field(errors, values, "first_name", validation.string:minlen(1), t("Provide your first name."))
  validate_field(errors, values, "last_name", validation.string:minlen(1), t("Provide your last name."))
  validate_field(errors, values, "email", validation.string:minlen(1), t("Provide your email address."))
  validate_field(errors, values, "email", validation:regex([[.+@.+\..+]], "jo"), t("Provide a valid email address."))
  validate_field(errors, values, "website", validation.optional:regex([[\w+\.\w+]], "jo"), t("Your website must be a valid URL in the form of http://example.com"))
  return errors
end

local save_options = {
  before_validate_on_create = before_validate_on_create,
  validate = validate,
}

local ApiUser = Model:extend("api_users", {
  update = model_ext.update(save_options),

  api_key_decrypted = function(self)
    local decrypted
    if self.api_key_encrypted and self.api_key_encrypted_iv then
      decrypted = encryptor.decrypt(self.api_key_encrypted, self.api_key_encrypted_iv, self.id)
    end

    return decrypted
  end,

  api_key_preview = function(self)
    local preview
    if self.api_key_prefix then
      preview = string.sub(self.api_key_prefix, 1, 6) .. "..."
    end

    return preview
  end,

  as_json = function(self)
    return {
      id = self.id or json_null,
      api_key_preview = self:api_key_preview() or json_null,
      email = self.email or json_null,
      email_verified = self.email_verified or json_null,
      first_name = self.first_name or json_null,
      last_name = self.last_name or json_null,
      use_description = self.use_description or json_null,
      registration_ip = self.registration_ip or json_null,
      registration_source = self.registration_source or json_null,
      registration_user_agent = self.registration_user_agent or json_null,
      registration_referer = self.registration_referer or json_null,
      registration_origin = self.registration_origin or json_null,
      throttle_by_ip = self.throttle_by_ip or json_null,
      roles = self.roles or json_null,
      settings = self.settings or json_null,
      disabled_at = self.disabled_at or json_null,
      created_at = iso8601.format_postgres(self.created_at) or json_null,
      created_by = self.created_by or json_null,
      updated_at = iso8601.format_postgres(self.updated_at) or json_null,
      updated_by = self.updated_by or json_null,
      deleted_at = json_null,
      version = 1,
    }
  end,
})

ApiUser.create = model_ext.create(save_options)

return ApiUser
