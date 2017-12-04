local api_scope_policy = require "api-umbrella.web-app.policies.api_scope_policy"
local common_validations = require "api-umbrella.web-app.utils.common_validations"
local json_null = require("cjson").null
local json_null_default = require "api-umbrella.web-app.utils.json_null_default"
local model_ext = require "api-umbrella.web-app.utils.model_ext"
local t = require("api-umbrella.web-app.utils.gettext").gettext
local time = require "api-umbrella.utils.time"
local validation_ext = require "api-umbrella.web-app.utils.validation_ext"

local validate_field = model_ext.validate_field
local validate_uniqueness = model_ext.validate_uniqueness

local ApiScope
ApiScope = model_ext.new_class("api_scopes", {
  display_name = function(self)
    return self.name .. " - " .. self.host .. self.path_prefix
  end,

  authorize = function(self)
    api_scope_policy.authorize_show(ngx.ctx.current_admin, self:attributes())
  end,

  as_json = function(self)
    return {
      id = json_null_default(self.id),
      name = json_null_default(self.name),
      host = json_null_default(self.host),
      path_prefix = json_null_default(self.path_prefix),
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

  is_root = function(self)
    return self.path_prefix == "/"
  end
}, {
  authorize = function(data)
    api_scope_policy.authorize_modify(ngx.ctx.current_admin, data)
  end,

  validate = function(_, data)
    local errors = {}
    validate_field(errors, data, "name", t("Name"), {
      { validation_ext.string:minlen(1), t("can't be blank"), }
    })
    validate_field(errors, data, "host", t("Host"), {
      { validation_ext.string:minlen(1), t("can't be blank") },
      { validation_ext:regex(common_validations.host_format_with_wildcard, "jo"), t('must be in the format of "example.com"') },
    })
    validate_field(errors, data, "path_prefix", t("Path prefix"), {
      { validation_ext.string:minlen(1), t("can't be blank") },
      { validation_ext:regex(common_validations.url_prefix_format, "jo"), t('must start with "/"') },
    })
    validate_uniqueness(errors, data, "path_prefix", t("Path prefix"), ApiScope, {
      "host",
      "path_prefix",
    })
    return errors
  end,
})

return ApiScope
