local Model = require("lapis.db.model").Model
local validation = require "resty.validation"
local iso8601 = require "api-umbrella.utils.iso8601"
local model_ext = require "api-umbrella.utils.model_ext"
local random_token = require "api-umbrella.utils.random_token"
local cjson = require "cjson"

local json_null = cjson.null
local validate_field = model_ext.validate_field

local function before_create(_, values)
  values["api_key"] = random_token(40)
end

local function validate(values)
  local errors = {}
  validate_field(errors, values, "first_name", validation.string:minlen(1), "Provide your first name.")
  validate_field(errors, values, "last_name", validation.string:minlen(1), "Provide your last name.")
  validate_field(errors, values, "email", validation.string:minlen(1), "Provide your email address.")
  validate_field(errors, values, "email", validation:regex([[.+@.+\..+]], "jo"), "Provide a valid email address.")
  validate_field(errors, values, "website", validation.optional:regex([[\w+\.\w+]], "jo"), "Your website must be a valid URL in the form of http://example.com")
  return errors
end

local ApiUser = Model:extend("api_users", {
  update = model_ext.update({ validate = validate }),

  api_key_preview = function(self)
    local preview
    if self.api_key then
      preview = string.sub(self.api_key, 1, 6) .. "..."
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

ApiUser.create = model_ext.create({
  before_create = before_create,
  validate = validate,
})

return ApiUser
