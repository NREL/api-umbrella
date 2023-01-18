local api_scope_policy = require "api-umbrella.web-app.policies.api_scope_policy"
local common_validations = require "api-umbrella.web-app.utils.common_validations"
local db = require "lapis.db"
local escape_db_like = require "api-umbrella.utils.escape_db_like"
local json_array_fields = require "api-umbrella.web-app.utils.json_array_fields"
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
  relations = {
    model_ext.has_and_belongs_to_many("admin_groups", "AdminGroup", {
      join_table = "admin_groups_api_scopes",
      foreign_key = "api_scope_id",
      association_foreign_key = "admin_group_id",
      order = "name",
    }),
    {
      "api_backends",
      fetch = function(self)
        local ApiBackend = require "api-umbrella.web-app.models.api_backend"

        local sql = "INNER JOIN api_backend_url_matches ON api_backends.id = api_backend_url_matches.api_backend_id" ..
          " WHERE api_backends.frontend_host = ?" ..
            " AND api_backend_url_matches.frontend_prefix LIKE ? || '%'" ..
          " GROUP BY api_backends.id" ..
          " ORDER BY api_backends.name"
        return ApiBackend:select(sql, self.host, escape_db_like(self.path_prefix), {
          fields = "api_backends.*",
        })
      end,
      preload = function(api_scopes)
        local ApiBackend = require "api-umbrella.web-app.models.api_backend"

        local api_scope_ids = {}
        for _, api_scope in ipairs(api_scopes) do
          api_scope["api_backends"] = {}
          table.insert(api_scope_ids, api_scope.id)
        end

        if #api_scope_ids > 0 then
          local sql = "INNER JOIN api_scopes ON api_backends.frontend_host = api_scopes.host" ..
            " INNER JOIN api_backend_url_matches ON api_backends.id = api_backend_url_matches.api_backend_id AND api_backend_url_matches.frontend_prefix LIKE api_scopes.path_prefix || '%' " ..
            " WHERE api_scopes.id IN ? " ..
            " GROUP BY api_backends.id, api_scopes.id" ..
            " ORDER BY api_backends.name"
          local api_backends = ApiBackend:select(sql, db.list(api_scope_ids), {
            fields = "api_backends.*, api_scopes.id AS _api_scope_id",
          })

          for _, api_backend in ipairs(api_backends) do
            for _, api_scope in ipairs(api_scopes) do
              if api_scope.id == api_backend["_api_scope_id"] then
                api_backend["_api_scope_id"] = nil
                table.insert(api_scope["api_backends"], api_backend)
              end
            end
          end
        end
      end,
    },
  },

  display_name = function(self)
    return self.name .. " - " .. self.host .. self.path_prefix
  end,

  authorize = function(self)
    api_scope_policy.authorize_show(ngx.ctx.current_admin, self:attributes())
  end,

  admin_groups_as_json = function(self)
    local admin_groups = {}
    for _, admin_group in ipairs(self:get_admin_groups()) do
      table.insert(admin_groups, admin_group:embedded_json())
    end

    return admin_groups
  end,

  admin_group_names = function(self)
    local admin_group_names = {}
    for _, admin_group in ipairs(self:get_admin_groups()) do
      table.insert(admin_group_names, admin_group.name)
    end

    return admin_group_names
  end,

  api_backends_as_json = function(self)
    local api_backends = {}
    for _, api_backend in ipairs(self:get_api_backends()) do
      table.insert(api_backends, api_backend:embedded_json())
    end

    return api_backends
  end,

  api_backend_names = function(self)
    local api_backend_names = {}
    for _, api_backend in ipairs(self:get_api_backends()) do
      table.insert(api_backend_names, api_backend.name)
    end

    return api_backend_names
  end,

  as_json = function(self)
    local data = {
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

    if ngx.ctx.current_admin.superuser then
      data["admin_groups"] = json_null_default(self:admin_groups_as_json())
      data["apis"] = json_null_default(self:api_backends_as_json())

      json_array_fields(data, {
        "admin_groups",
        "apis",
      })
    end

    return data
  end,

  embedded_json = function(self)
    return {
      id = json_null_default(self.id),
      name = json_null_default(self.name),
      host = json_null_default(self.host),
      path_prefix = json_null_default(self.path_prefix),
    }
  end,

  csv_headers = function()
    local headers = {
      t("Name"),
      t("Host"),
      t("Path Prefix"),
    }

    if ngx.ctx.current_admin then
      table.insert(headers, t("Admin Groups"))
      table.insert(headers, t("API Backends"))
    end

    return headers
  end,

  as_csv = function(self)
    local data = {
      json_null_default(self.name),
      json_null_default(self.host),
      json_null_default(self.path_prefix),
    }

    if ngx.ctx.current_admin.superuser then
      table.insert(data, json_null_default(table.concat(self:admin_group_names(), "\n")))
      table.insert(data, json_null_default(table.concat(self:api_backend_names(), "\n")))
    end

    return data
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
      { validation_ext.string:minlen(1), t("can't be blank"), },
      { validation_ext.db_null_optional.string:maxlen(255), string.format(t("is too long (maximum is %d characters)"), 255) },
    })
    validate_field(errors, data, "host", t("Host"), {
      { validation_ext.string:minlen(1), t("can't be blank") },
      { validation_ext.db_null_optional.string:maxlen(255), string.format(t("is too long (maximum is %d characters)"), 255) },
      { validation_ext.db_null_optional:regex(common_validations.host_format_with_wildcard, "jo"), t('must be in the format of "example.com"') },
    })
    validate_field(errors, data, "path_prefix", t("Path prefix"), {
      { validation_ext.string:minlen(1), t("can't be blank") },
      { validation_ext.db_null_optional.string:maxlen(255), string.format(t("is too long (maximum is %d characters)"), 255) },
      { validation_ext.db_null_optional:regex(common_validations.url_prefix_format, "jo"), t('must start with "/"') },
    })
    validate_uniqueness(errors, data, "path_prefix", t("Path prefix"), ApiScope, {
      "host",
      "path_prefix",
    })
    return errors
  end,
})

return ApiScope
