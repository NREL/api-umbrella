local ApiRole = require "api-umbrella.web-app.models.api_role"
local ApiUserSettings = require "api-umbrella.web-app.models.api_user_settings"
local api_user_policy = require "api-umbrella.web-app.policies.api_user_policy"
local cjson = require "cjson"
local encryptor = require "api-umbrella.utils.encryptor"
local hmac = require "api-umbrella.utils.hmac"
local is_empty = require("pl.types").is_empty
local json_array_fields = require "api-umbrella.web-app.utils.json_array_fields"
local json_null_default = require "api-umbrella.web-app.utils.json_null_default"
local model_ext = require "api-umbrella.web-app.utils.model_ext"
local random_token = require "api-umbrella.utils.random_token"
local t = require("api-umbrella.web-app.utils.gettext").gettext
local time = require "api-umbrella.utils.time"
local validation_ext = require "api-umbrella.web-app.utils.validation_ext"

local json_null = cjson.null
local validate_field = model_ext.validate_field

local API_KEY_PREFIX_LENGTH = 14

local ApiUser
ApiUser = model_ext.new_class("api_users", {
  relations = {
    { "settings", has_one = "ApiUserSettings" },
    model_ext.has_and_belongs_to_many("roles", "ApiRole", {
      join_table = "api_users_roles",
      foreign_key = "api_user_id",
      association_foreign_key = "api_role_id",
      order = "id",
    }),
  },

  attributes = function(self, options)
    if not options then
      options = {
        includes = {
          roles = {},
          settings = {
            includes = {
              rate_limits = {},
            },
          },
        },
      }
    end

    return model_ext.record_attributes(self, options)
  end,

  authorize = function(self)
    api_user_policy.authorize_show(ngx.ctx.current_admin, self:attributes())
  end,

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

  api_key_hides_at = function(self)
    if not self._api_key_hides_at then
      local hides_at = time.postgres_to_timestamp(self.created_at)
      if hides_at then
        hides_at = hides_at + 14 * 24 * 60 * 60 -- 14 days
      end

      self._api_key_hides_at = hides_at
    end

    return self._api_key_hides_at
  end,

  admin_can_view_api_key = function(self)
    local allowed = false
    if ngx.ctx.current_admin then
      if ngx.ctx.current_admin.superuser then
        allowed = true
      elseif ngx.now() < self:api_key_hides_at() then
        local roles = self:get_roles()
        if is_empty(roles) then
          allowed = true
        elseif self.created_by_id and ngx.ctx.current_admin.id and self.created_by_id == ngx.ctx.current_admin.id then
          allowed = true
        end
      end
    end

    return allowed
  end,

  role_ids = function(self)
    local role_ids = {}
    for _, role in ipairs(self:get_roles()) do
      table.insert(role_ids, role.id)
    end

    return role_ids
  end,

  enabled = function(self)
    if self.disabled_at then
      return false
    else
      return true
    end
  end,

  as_json = function(self, options)
    local updated_at = time.postgres_to_timestamp(self.updated_at)
    local data = {
      id = json_null_default(self.id),
      email = json_null_default(self.email),
      first_name = json_null_default(self.first_name),
      last_name = json_null_default(self.last_name),
      use_description = json_null_default(self.use_description),
      website = json_null_default(self.website),
      registration_source = json_null_default(self.registration_source),
      throttle_by_ip = json_null_default(self.throttle_by_ip),
      roles = json_null_default(self:role_ids()),
      settings = json_null,
      enabled = self:enabled(),
      disabled_at = json_null_default(time.postgres_to_iso8601(self.disabled_at)),
      ts = {
        ["$timestamp"] = {
          t = json_null_default(math.floor(updated_at)),
          i = 1,
        },
      },
      created_at = json_null_default(time.postgres_to_iso8601(self.created_at)),
      created_by = json_null_default(self.created_by_id),
      creator = {
        username = json_null_default(self.created_by_username),
      },
      updated_at = json_null_default(time.timestamp_to_iso8601(updated_at)),
      updated_by = json_null_default(self.updated_by_id),
      updater = {
        username = json_null_default(self.updated_by_username),
      },
      deleted_at = json_null,
      version = 1,
    }

    if ngx.ctx.current_admin then
      data["api_key_preview"] = json_null_default(self:api_key_preview())
      data["email_verified"] = json_null_default(self.email_verified)
      data["registration_ip"] = json_null_default(self.registration_ip)
      data["registration_origin"] = json_null_default(self.registration_origin)
      data["registration_referer"] = json_null_default(self.registration_referer)
      data["registration_user_agent"] = json_null_default(self.registration_user_agent)

      if options and options["allow_api_key"] and self:admin_can_view_api_key() then
        data["api_key"] = json_null_default(self:api_key_decrypted())
        data["api_key_hides_at"] = json_null_default(time.timestamp_to_iso8601(self:api_key_hides_at()))
      end
    end

    local settings = self:get_settings()
    if settings then
      data["settings"] = settings:as_json(options)

      -- Add legacy "_id" fields on the embedded rate limits.
      --
      -- We never intended to return this (everything else returns just "id"),
      -- but we accidentally included "_id" on the "show" endpoint for API
      -- users. So keep returning for backwards compatibility, but should
      -- remove for V2 of APIs.
      if data["settings"]["rate_limits"] then
        for _, rate_limit in ipairs(data["settings"]["rate_limits"]) do
          rate_limit["_id"] = rate_limit["id"]
        end
      end
    end

    json_array_fields(data, {"roles"}, options)

    return data
  end,

  settings_update_or_create = function(self, settings_values)
    return model_ext.has_one_update_or_create(self, ApiUserSettings, "api_user_id", settings_values)
  end,

  settings_delete = function(self)
    return model_ext.has_one_delete(self, ApiUserSettings, "api_user_id", {})
  end,
}, {
  authorize = function(data, action)
    if action == "create" then
      api_user_policy.authorize_create(ngx.ctx.current_admin, data)
    else
      api_user_policy.authorize_modify(ngx.ctx.current_admin, data)
    end
  end,

  before_validate_on_create = function(_, values)
    local api_key = random_token(40)
    values["api_key_hash"] = hmac(api_key)
    local encrypted, iv = encryptor.encrypt(api_key, values["id"])
    values["api_key_encrypted"] = encrypted
    values["api_key_encrypted_iv"] = iv
    values["api_key_prefix"] = string.sub(api_key, 1, API_KEY_PREFIX_LENGTH)
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
    model_ext.has_one_save(self, values, "settings")
    ApiRole.insert_missing(values["role_ids"])
    model_ext.save_has_and_belongs_to_many(self, values["role_ids"], {
      join_table = "api_users_roles",
      foreign_key = "api_user_id",
      association_foreign_key = "api_role_id",
    })
  end,
})

ApiUser.API_KEY_PREFIX_LENGTH = API_KEY_PREFIX_LENGTH

return ApiUser
