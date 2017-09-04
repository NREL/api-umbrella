local ApiRole = require "api-umbrella.lapis.models.api_role"
local cjson = require "cjson"
local encryptor = require "api-umbrella.utils.encryptor"
local hmac = require "api-umbrella.utils.hmac"
local iso8601 = require "api-umbrella.utils.iso8601"
local model_ext = require "api-umbrella.utils.model_ext"
local random_token = require "api-umbrella.utils.random_token"
local t = require("resty.gettext").gettext
local validation_ext = require "api-umbrella.utils.validation_ext"

local json_null = cjson.null
local validate_field = model_ext.validate_field

local ApiUser = model_ext.new_class("api_users", {
  relations = {
    model_ext.has_and_belongs_to_many("roles", "ApiRole", {
      join_table = "api_users_roles",
      foreign_key = "api_user_id",
      association_foreign_key = "api_role_id",
      order = "id",
    }),
  },

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

  role_ids = function(self)
    local role_ids = {}
    for _, role in ipairs(self:get_roles()) do
      table.insert(role_ids, role.id)
    end

    return role_ids
  end,

  as_json = function(self)
    local data = {
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
      roles = self:role_ids() or json_null,
      settings = self.settings or json_null,
      disabled_at = self.disabled_at or json_null,
      created_at = iso8601.format_postgres(self.created_at) or json_null,
      created_by = self.created_by or json_null,
      updated_at = iso8601.format_postgres(self.updated_at) or json_null,
      updated_by = self.updated_by or json_null,
      deleted_at = json_null,
      version = 1,
    }
    setmetatable(data["roles"], cjson.empty_array_mt)

    return data
  end,
}, {
  authorize = function()
    return true
  end,

  before_validate_on_create = function(_, values)
    local api_key = random_token(40)
    values["api_key_hash"] = hmac(api_key)
    local encrypted, iv = encryptor.encrypt(api_key, values["id"])
    values["api_key_encrypted"] = encrypted
    values["api_key_encrypted_iv"] = iv
    values["api_key_prefix"] = string.sub(api_key, 1, 10)
  end,

  validate = function(_, data)
    local errors = {}
    validate_field(errors, data, "first_name", validation_ext.string:minlen(1), t("Provide your first name."))
    validate_field(errors, data, "last_name", validation_ext.string:minlen(1), t("Provide your last name."))
    validate_field(errors, data, "email", validation_ext.string:minlen(1), t("Provide your email address."))
    validate_field(errors, data, "email", validation_ext:regex([[.+@.+\..+]], "jo"), t("Provide a valid email address."))
    validate_field(errors, data, "website", validation_ext.db_null_optional:regex([[\w+\.\w+]], "jo"), t("Your website must be a valid URL in the form of http://example.com"))
    return errors
  end,

  after_save = function(self, values)
    ApiRole.insert_missing(values["roles"])
    model_ext.save_has_and_belongs_to_many(self, values["roles"], {
      join_table = "api_users_roles",
      foreign_key = "api_user_id",
      association_foreign_key = "api_role_id",
    })
  end,
})

return ApiUser
