local iso8601 = require "api-umbrella.utils.iso8601"
local common_validations = require "api-umbrella.utils.common_validations"
local t = require("resty.gettext").gettext
local validation_ext = require "api-umbrella.utils.validation_ext"
local json_null = require("cjson").null
local model_ext = require "api-umbrella.utils.model_ext"
local website_backend_policy = require "api-umbrella.lapis.policies.website_backend_policy"

local validate_field = model_ext.validate_field
local validate_uniqueness = model_ext.validate_uniqueness

local WebsiteBackend
WebsiteBackend = model_ext.new_class("website_backends", {
  attributes = function(self)
    return model_ext.record_attributes(self)
  end,

  authorize = function(self)
    website_backend_policy.authorize_show(ngx.ctx.current_admin, self:attributes())
  end,

  as_json = function(self)
    return {
      id = self.id or json_null,
      frontend_host = self.frontend_host or json_null,
      backend_protocol = self.backend_protocol or json_null,
      server_host = self.server_host or json_null,
      server_port = self.server_port or json_null,
      created_at = iso8601.format_postgres(self.created_at) or json_null,
      created_by = self.created_by_id or json_null,
      creator = {
        username = self.created_by_username or json_null,
      },
      updated_at = iso8601.format_postgres(self.updated_at) or json_null,
      updated_by = self.updated_by_id or json_null,
      updater = {
        username = self.updated_by_username or json_null,
      },
      deleted_at = json_null,
      version = 1,
    }
  end,
}, {
  authorize = function(data)
    website_backend_policy.authorize_modify(ngx.ctx.current_admin, data)
  end,

  validate = function(_, data)
    local errors = {}
    validate_field(errors, data, "frontend_host", validation_ext.string:minlen(1), t("can't be blank"))
    validate_field(errors, data, "frontend_host", validation_ext.db_null_optional:regex(common_validations.host_format_with_wildcard, "jo"), t('must be in the format of "example.com"'))
    validate_field(errors, data, "backend_protocol", validation_ext:regex("^(http|https)$", "jo"), t("is not included in the list"))
    validate_field(errors, data, "server_host", validation_ext.string:minlen(1), t("can't be blank"))
    validate_field(errors, data, "server_host", validation_ext.db_null_optional:regex(common_validations.host_format, "jo"), t('must be in the format of "example.com"'))
    validate_field(errors, data, "server_port", validation_ext.number, t("can't be blank"))
    validate_field(errors, data, "server_port", validation_ext.number:between(0, 65535), t("is not included in the list"))
    validate_uniqueness(errors, data, "frontend_host", WebsiteBackend, { "frontend_host" })
    return errors
  end,
})

WebsiteBackend.all_sorted = function(where)
  local sql = ""
  if where then
    sql = sql .. "WHERE " .. where
  end
  sql = sql .. " ORDER BY frontend_host"

  return WebsiteBackend:select(sql)
end

return WebsiteBackend
