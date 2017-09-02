local cjson = require "cjson"
local iso8601 = require "api-umbrella.utils.iso8601"
local model_ext = require "api-umbrella.utils.model_ext"
local t = require("resty.gettext").gettext
local validation_ext = require "api-umbrella.utils.validation_ext"

local json_null = cjson.null
local validate_field = model_ext.validate_field

local AdminGroup = model_ext.new_class("admin_groups", {
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

  admins_as_json = function(self)
    local admins = {}
    for _, admin in ipairs(self:get_admins()) do
      table.insert(admins, {
        id = admin.id,
        username = admin.username,
        last_sign_in_at = admin.last_sign_in_at,
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

  as_json = function(self)
    local data = {
      id = self.id or json_null,
      name = self.name or json_null,
      created_at = iso8601.format_postgres(self.created_at) or json_null,
      created_by = self.created_by or json_null,
      updated_at = iso8601.format_postgres(self.updated_at) or json_null,
      updated_by = self.updated_by or json_null,
      api_scope_ids = self:api_scope_ids() or json_null,
      api_scope_display_names = self:api_scope_display_names() or json_null,
      permission_ids = self:permission_ids() or json_null,
      permission_display_names = self:permission_names() or json_null,
      admins = self:admins_as_json() or json_null,
      admin_usernames = self:admin_usernames() or json_null,
      deleted_at = json_null,
      version = 1,
    }
    setmetatable(data["api_scope_ids"], cjson.empty_array_mt)
    setmetatable(data["api_scope_display_names"], cjson.empty_array_mt)
    setmetatable(data["permission_ids"], cjson.empty_array_mt)
    setmetatable(data["permission_display_names"], cjson.empty_array_mt)
    setmetatable(data["admins"], cjson.empty_array_mt)
    setmetatable(data["admin_usernames"], cjson.empty_array_mt)
    return data
  end,
}, {
  validate = function(_, data)
    local errors = {}
    validate_field(errors, data, "name", validation_ext.string:minlen(1), t("can't be blank"))
    validate_field(errors, data, "api_scope_ids", validation_ext.table:minlen(1), t("can't be blank"))
    validate_field(errors, data, "permission_ids", validation_ext.table:minlen(1), t("can't be blank"))
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

return AdminGroup
