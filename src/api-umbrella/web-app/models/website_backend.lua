local common_validations = require "api-umbrella.web-app.utils.common_validations"
local json_null = require("cjson").null
local json_null_default = require "api-umbrella.web-app.utils.json_null_default"
local model_ext = require "api-umbrella.web-app.utils.model_ext"
local t = require("api-umbrella.web-app.utils.gettext").gettext
local time = require "api-umbrella.utils.time"
local validation_ext = require "api-umbrella.web-app.utils.validation_ext"
local website_backend_policy = require "api-umbrella.web-app.policies.website_backend_policy"

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
      id = json_null_default(self.id),
      frontend_host = json_null_default(self.frontend_host),
      backend_protocol = json_null_default(self.backend_protocol),
      server_host = json_null_default(self.server_host),
      server_port = json_null_default(self.server_port),
      created_order = json_null_default(self.created_order),
      created_at = json_null_default(time.postgres_to_iso8601(self.created_at)),
      created_by = json_null_default(self.created_by_id),
      creator = {
        username = json_null_default(self.created_by_username),
      },
      updated_at = json_null_default(time.postgres_to_iso8601(self.updated_at)),
      updated_by = json_null_default(self.updated_by_id),
      updater = {
        username = json_null_default(self.updated_by_username),
      },
      deleted_at = json_null,
      version = 1,
    }
  end,

  csv_headers = function()
    return {
      t("Host"),
    }
  end,

  as_csv = function(self)
    return {
      json_null_default(self.frontend_host),
    }
  end,
}, {
  authorize = function(data)
    website_backend_policy.authorize_modify(ngx.ctx.current_admin, data)
  end,

  validate = function(_, data)
    local errors = {}
    validate_field(errors, data, "frontend_host", t("Frontend host"), {
      { validation_ext.string:minlen(1), t("can't be blank") },
      { validation_ext.db_null_optional.string:maxlen(255), string.format(t("is too long (maximum is %d characters)"), 255) },
      { validation_ext.db_null_optional:regex(common_validations.host_format_with_wildcard, "jo"), t('must be in the format of "example.com"') },
    })
    validate_field(errors, data, "backend_protocol", t("Backend protocol"), {
      { validation_ext:regex("^(http|https)$", "jo"), t("is not included in the list") },
    })
    validate_field(errors, data, "server_host", t("Server host"), {
      { validation_ext.string:minlen(1), t("can't be blank") },
      { validation_ext.db_null_optional.string:maxlen(255), string.format(t("is too long (maximum is %d characters)"), 255) },
      { validation_ext.db_null_optional:regex(common_validations.host_format, "jo"), t('must be in the format of "example.com"') },
    })
    validate_field(errors, data, "server_port", t("Server port"), {
      { validation_ext.tonumber.number, t("can't be blank") },
      { validation_ext.tonumber.number:between(0, 65535), t("is not included in the list") },
    })
    validate_uniqueness(errors, data, "frontend_host", t("Frontend host"), WebsiteBackend, { "frontend_host" })
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
