local admin_group_policy = require "api-umbrella.web-app.policies.admin_group_policy"
local cjson = require "cjson"
local db = require "lapis.db"
local invert_table = require "api-umbrella.utils.invert_table"
local is_array = require "api-umbrella.utils.is_array"
local is_empty = require "api-umbrella.utils.is_empty"
local json_array_fields = require "api-umbrella.web-app.utils.json_array_fields"
local json_null_default = require "api-umbrella.web-app.utils.json_null_default"
local model_ext = require "api-umbrella.web-app.utils.model_ext"
local t = require("api-umbrella.web-app.utils.gettext").gettext
local time = require "api-umbrella.utils.time"
local validation_ext = require "api-umbrella.web-app.utils.validation_ext"

local db_null = db.NULL
local json_null = cjson.null
local validate_field = model_ext.validate_field
local validate_uniqueness = model_ext.validate_uniqueness

local AdminGroup
AdminGroup = model_ext.new_class("admin_groups", {
  relations = {
    model_ext.has_and_belongs_to_many("admins", "Admin", {
      join_table = "admin_groups_admins",
      foreign_key = "admin_group_id",
      association_foreign_key = "admin_id",
      order = "username",
    }),
    model_ext.has_and_belongs_to_many("api_scopes", "ApiScope", {
      join_table = "admin_groups_api_scopes",
      foreign_key = "admin_group_id",
      association_foreign_key = "api_scope_id",
      order = "name",
    }),
    model_ext.has_and_belongs_to_many("permissions", "AdminPermission", {
      join_table = "admin_groups_admin_permissions",
      foreign_key = "admin_group_id",
      association_foreign_key = "admin_permission_id",
      order = "display_order",
    }),
  },

  attributes = function(self, options)
    if not options then
      options = {
        includes = {
          admins = {},
          api_scopes = {},
          permissions = {},
        },
      }
    end

    return model_ext.record_attributes(self, options)
  end,

  authorize = function(self)
    admin_group_policy.authorize_show(ngx.ctx.current_admin, self:attributes())
  end,

  admins_as_json = function(self)
    local admins = {}
    for _, admin in ipairs(self:get_admins()) do
      table.insert(admins, {
        id = admin.id,
        username = admin.username,
        current_sign_in_at = json_null_default(time.postgres_to_iso8601(admin.current_sign_in_at)),
        last_sign_in_at = json_null_default(time.postgres_to_iso8601(admin.last_sign_in_at)),
      })
    end

    return admins
  end,

  admin_usernames = function(self)
    local admin_usernames = {}
    for _, admin in ipairs(self:get_admins()) do
      table.insert(admin_usernames, admin.username)
    end

    return admin_usernames
  end,

  api_scopes_as_json = function(self)
    local api_scopes = {}
    for _, api_scope in ipairs(self:get_api_scopes()) do
      table.insert(api_scopes, api_scope:embedded_json())
    end

    return api_scopes
  end,

  api_scope_ids = function(self)
    local api_scope_ids = {}
    for _, api_scope in ipairs(self:get_api_scopes()) do
      table.insert(api_scope_ids, api_scope.id)
    end

    return api_scope_ids
  end,

  api_scope_display_names = function(self)
    local api_scope_display_names = {}
    for _, api_scope in ipairs(self:get_api_scopes()) do
      table.insert(api_scope_display_names, api_scope:display_name())
    end

    return api_scope_display_names
  end,

  permission_ids = function(self)
    local permission_ids = {}
    for _, permission in ipairs(self:get_permissions()) do
      table.insert(permission_ids, permission.id)
    end

    return permission_ids
  end,

  permission_names = function(self)
    local permission_names = {}
    for _, permission in ipairs(self:get_permissions()) do
      table.insert(permission_names, permission.name)
    end

    return permission_names
  end,

  allows_permission = function(self, permission_id)
    assert(permission_id)

    for _, id in ipairs(self:permission_ids()) do
      if id == permission_id then
        return true
      end
    end

    return false
  end,

  as_json = function(self, options)
    local data = {
      id = json_null_default(self.id),
      name = json_null_default(self.name),
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
      api_scopes = json_null_default(self:api_scopes_as_json()),
      api_scope_ids = json_null_default(self:api_scope_ids()),
      api_scope_display_names = json_null_default(self:api_scope_display_names()),
      permission_ids = json_null_default(self:permission_ids()),
      permission_display_names = json_null_default(self:permission_names()),
      admins = json_null_default(self:admins_as_json()),
      admin_usernames = json_null_default(self:admin_usernames()),
      deleted_at = json_null,
      version = 1,
    }

    json_array_fields(data, {
      "api_scopes",
      "api_scope_ids",
      "api_scope_display_names",
      "permission_ids",
      "permission_display_names",
      "admins",
      "admin_usernames",
    }, options)

    return data
  end,

  embedded_json = function(self)
    return {
      id = json_null_default(self.id),
      name = json_null_default(self.name),
    }
  end,

  csv_headers = function()
    return {
      t("Name"),
      t("API Scopes"),
      t("Access"),
      t("Admins"),
    }
  end,

  as_csv = function(self)
    return {
      json_null_default(self.name),
      json_null_default(table.concat(self:api_scope_display_names(), "\n")),
      json_null_default(table.concat(self:permission_names(), "\n")),
      json_null_default(table.concat(self:admin_usernames(), "\n")),
    }
  end,
}, {
  authorize = function(data)
    admin_group_policy.authorize_modify(ngx.ctx.current_admin, data)
  end,

  validate = function(_, data)
    local errors = {}
    validate_field(errors, data, "name", t("Name"), {
      { validation_ext.string:minlen(1), t("can't be blank") },
      { validation_ext.db_null_optional.string:maxlen(255), string.format(t("is too long (maximum is %d characters)"), 255) },
    })
    validate_field(errors, data, "api_scope_ids", t("API scopes"), {
      { validation_ext.non_null_table:minlen(1), t("can't be blank") },
    }, { error_field = "api_scopes" })
    validate_field(errors, data, "permission_ids", t("Permissions"), {
      { validation_ext.non_null_table:minlen(1), t("can't be blank") },
    }, { error_field = "permissions" })
    validate_uniqueness(errors, data, "name", t("Name"), AdminGroup, { "name" })

    if data["permission_ids"] ~= db_null and is_array(data["permission_ids"]) then
      local permissions = invert_table(data["permission_ids"])

      if permissions["user_manage"] and not permissions["user_view"] then
        model_ext.add_error(errors, "permission_ids", t("Permissions"), t("user_view permission must be included if user_manage is enabled"))
      end

      if permissions["admin_manage"] and not permissions["admin_view"] then
        model_ext.add_error(errors, "permission_ids", t("Permissions"), t("admin_view permission must be included if admin_manage is enabled"))
      end
    end

    return errors
  end,

  after_save = function(self, values)
    model_ext.save_has_and_belongs_to_many(self, values["api_scope_ids"], {
      join_table = "admin_groups_api_scopes",
      foreign_key = "admin_group_id",
      association_foreign_key = "api_scope_id",
    })

    model_ext.save_has_and_belongs_to_many(self, values["permission_ids"], {
      join_table = "admin_groups_admin_permissions",
      foreign_key = "admin_group_id",
      association_foreign_key = "admin_permission_id",
    })
  end,
})

AdminGroup.api_scope_ids_for_admin_group_ids = function(admin_group_ids)
  local api_scope_ids = {}
  if not is_empty(admin_group_ids) then
    local rows = db.query("SELECT DISTINCT api_scope_id FROM admin_groups_api_scopes WHERE admin_group_id IN ?", db.list(admin_group_ids))
    for _, row in ipairs(rows) do
      table.insert(api_scope_ids, row["api_scope_id"])
    end
  end

  return api_scope_ids
end

return AdminGroup
