local admin_group_policy = require "api-umbrella.lapis.policies.admin_group_policy"
local cjson = require "cjson"
local db = require "lapis.db"
local is_empty = require("pl.types").is_empty
local iso8601 = require "api-umbrella.utils.iso8601"
local json_array_fields = require "api-umbrella.lapis.utils.json_array_fields"
local model_ext = require "api-umbrella.utils.model_ext"
local t = require("resty.gettext").gettext
local validation_ext = require "api-umbrella.utils.validation_ext"

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
        last_sign_in_at = iso8601.format_postgres(admin.last_sign_in_at) or json_null,
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
      id = self.id or json_null,
      name = self.name or json_null,
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
      api_scope_ids = self:api_scope_ids() or json_null,
      api_scope_display_names = self:api_scope_display_names() or json_null,
      permission_ids = self:permission_ids() or json_null,
      permission_display_names = self:permission_names() or json_null,
      admins = self:admins_as_json() or json_null,
      admin_usernames = self:admin_usernames() or json_null,
      deleted_at = json_null,
      version = 1,
    }

    json_array_fields(data, {
      "api_scope_ids",
      "api_scope_display_names",
      "permission_ids",
      "permission_display_names",
      "admins",
      "admin_usernames",
    }, options)

    return data
  end,
}, {
  authorize = function(data)
    admin_group_policy.authorize_modify(ngx.ctx.current_admin, data)
  end,

  validate = function(_, data)
    local errors = {}
    validate_field(errors, data, "name", validation_ext.string:minlen(1), t("can't be blank"))
    validate_field(errors, data, "api_scope_ids", validation_ext.non_null_table:minlen(1), t("can't be blank"), { error_field = "api_scopes" })
    validate_field(errors, data, "permission_ids", validation_ext.non_null_table:minlen(1), t("can't be blank"), { error_field = "permissions" })
    validate_uniqueness(errors, data, "name", AdminGroup, { "name" })
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
