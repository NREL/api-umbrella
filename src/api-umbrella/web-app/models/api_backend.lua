local ApiBackendRewrite = require "api-umbrella.web-app.models.api_backend_rewrite"
local ApiBackendServer = require "api-umbrella.web-app.models.api_backend_server"
local ApiBackendSettings = require "api-umbrella.web-app.models.api_backend_settings"
local ApiBackendSubUrlSettings = require "api-umbrella.web-app.models.api_backend_sub_url_settings"
local ApiBackendUrlMatch = require "api-umbrella.web-app.models.api_backend_url_match"
local api_backend_policy = require "api-umbrella.web-app.policies.api_backend_policy"
local common_validations = require "api-umbrella.web-app.utils.common_validations"
local db = require "lapis.db"
local is_array = require "api-umbrella.utils.is_array"
local json_array_fields = require "api-umbrella.web-app.utils.json_array_fields"
local json_null = require("cjson").null
local json_null_default = require "api-umbrella.web-app.utils.json_null_default"
local model_ext = require "api-umbrella.web-app.utils.model_ext"
local t = require("api-umbrella.web-app.utils.gettext").gettext
local time = require "api-umbrella.utils.time"
local validation_ext = require "api-umbrella.web-app.utils.validation_ext"

local db_null = db.NULL
local validate_field = model_ext.validate_field
local validate_relation_uniqueness = model_ext.validate_relation_uniqueness

local function add_sort_order_from_array_order(array)
  if is_array(array) and array ~= db_null then
    for index, values in ipairs(array) do
      if values["sort_order"] == nil or values["sort_order"] == db_null then
        values["sort_order"] = index
      end
    end
  end
end

local ApiBackend
ApiBackend = model_ext.new_class("api_backends", {
  relations = {
    {
      "rewrites",
      has_many = "ApiBackendRewrite",
      order = "sort_order",
    },
    {
      "servers",
      has_many = "ApiBackendServer",
      order = "host, port",
    },
    {
      "settings",
      has_one = "ApiBackendSettings",
    },
    {
      "sub_settings",
      has_many = "ApiBackendSubUrlSettings",
      order = "sort_order",
    },
    {
      "url_matches",
      has_many = "ApiBackendUrlMatch",
      order = "path_sort_order(frontend_prefix) NULLS LAST",
    },
    {
      "api_scopes",
      fetch = function(self)
        local ApiScope = require "api-umbrella.web-app.models.api_scope"

        local sql = "INNER JOIN api_backends ON api_scopes.host = api_backends.frontend_host" ..
          " INNER JOIN api_backend_url_matches ON api_backends.id = api_backend_url_matches.api_backend_id AND api_backend_url_matches.frontend_prefix LIKE api_scopes.path_prefix || '%' " ..
          " WHERE api_backends.id = ?" ..
          " GROUP BY api_scopes.id" ..
          " ORDER BY api_scopes.name"
        return ApiScope:select(sql, self.id, {
          fields = "api_scopes.*",
        })
      end,
      preload = function(api_backends)
        local ApiScope = require "api-umbrella.web-app.models.api_scope"

        local api_backend_ids = {}
        for _, api_backend in ipairs(api_backends) do
          api_backend["api_scopes"] = {}
          table.insert(api_backend_ids, api_backend.id)
        end

        if #api_backend_ids > 0 then
          local sql = "INNER JOIN api_backends ON api_scopes.host = api_backends.frontend_host" ..
            " INNER JOIN api_backend_url_matches ON api_backends.id = api_backend_url_matches.api_backend_id AND api_backend_url_matches.frontend_prefix LIKE api_scopes.path_prefix || '%' " ..
            " WHERE api_backends.id IN ?" ..
            " GROUP BY api_scopes.id, api_backends.id" ..
            " ORDER BY api_scopes.name"
          local api_scopes = ApiScope:select(sql, db.list(api_backend_ids), {
            fields = "api_scopes.*, api_backends.id AS _api_backend_id",
          })

          for _, api_scope in ipairs(api_scopes) do
            for _, api_backend in ipairs(api_backends) do
              if api_backend.id == api_scope["_api_backend_id"] then
                api_backend["_api_backend_id"] = nil
                table.insert(api_backend["api_scopes"], api_scope)
              end
            end
          end
        end
      end,
    },
    {
      "root_api_scope",
      fetch = function(self)
        local ApiScope = require "api-umbrella.web-app.models.api_scope"

        local sql = "INNER JOIN api_backends ON api_scopes.host = api_backends.frontend_host" ..
          " INNER JOIN api_backend_url_matches ON api_backends.id = api_backend_url_matches.api_backend_id AND api_backend_url_matches.frontend_prefix LIKE api_scopes.path_prefix || '%' " ..
          " WHERE api_backends.id = ?" ..
          " GROUP BY api_scopes.id" ..
          " ORDER BY length(api_scopes.path_prefix)" ..
          " LIMIT 1"
        return ApiScope:select(sql, self.id, {
          fields = "api_scopes.*",
        })[1]
      end,
      preload = function(api_backends)
        local ApiScope = require "api-umbrella.web-app.models.api_scope"

        local api_backend_ids = {}
        for _, api_backend in ipairs(api_backends) do
          table.insert(api_backend_ids, api_backend.id)
        end

        if #api_backend_ids > 0 then
          local sql = "INNER JOIN api_backends ON api_scopes.host = api_backends.frontend_host" ..
            " INNER JOIN api_backend_url_matches ON api_backends.id = api_backend_url_matches.api_backend_id AND api_backend_url_matches.frontend_prefix LIKE api_scopes.path_prefix || '%' " ..
            " WHERE api_backends.id IN ?" ..
            " GROUP BY api_scopes.id, api_backends.id" ..
            " ORDER BY api_backends.id, length(api_scopes.path_prefix)"
          local api_scopes = ApiScope:select(sql, db.list(api_backend_ids), {
            fields = "DISTINCT ON (api_backends.id) api_scopes.*, api_backends.id AS _api_backend_id",
          })

          for _, api_scope in ipairs(api_scopes) do
            for _, api_backend in ipairs(api_backends) do
              if api_backend.id == api_scope["_api_backend_id"] then
                api_backend["_api_backend_id"] = nil
                api_backend["root_api_scope"] = api_scope
              end
            end
          end
        end
      end,
    },
    {
      "admin_groups",
      fetch = function(self)
        local AdminGroup = require "api-umbrella.web-app.models.admin_group"

        local sql = "INNER JOIN admin_groups_api_scopes ON admin_groups.id = admin_groups_api_scopes.admin_group_id" ..
          " INNER JOIN api_scopes ON admin_groups_api_scopes.api_scope_id = api_scopes.id" ..
          " INNER JOIN api_backends ON api_scopes.host = api_backends.frontend_host" ..
          " INNER JOIN api_backend_url_matches ON api_backends.id = api_backend_url_matches.api_backend_id AND api_backend_url_matches.frontend_prefix LIKE api_scopes.path_prefix || '%' " ..
          " WHERE api_backends.id = ?" ..
          " GROUP BY admin_groups.id" ..
          " ORDER BY admin_groups.name"
        return AdminGroup:select(sql, self.id, {
          fields = "admin_groups.*",
        })
      end,
      preload = function(api_backends)
        local AdminGroup = require "api-umbrella.web-app.models.admin_group"

        local api_backend_ids = {}
        for _, api_backend in ipairs(api_backends) do
          api_backend["admin_groups"] = {}
          table.insert(api_backend_ids, api_backend.id)
        end

        if #api_backend_ids > 0 then
          local sql = "INNER JOIN admin_groups_api_scopes ON admin_groups.id = admin_groups_api_scopes.admin_group_id" ..
            " INNER JOIN api_scopes ON admin_groups_api_scopes.api_scope_id = api_scopes.id" ..
            " INNER JOIN api_backends ON api_scopes.host = api_backends.frontend_host" ..
            " INNER JOIN api_backend_url_matches ON api_backends.id = api_backend_url_matches.api_backend_id AND api_backend_url_matches.frontend_prefix LIKE api_scopes.path_prefix || '%' " ..
            " WHERE api_backends.id IN ?" ..
            " GROUP BY admin_groups.id, api_backends.id" ..
            " ORDER BY admin_groups.name"
          local admin_groups = AdminGroup:select(sql, db.list(api_backend_ids), {
            fields = "admin_groups.*, api_backends.id AS _api_backend_id",
          })

          for _, admin_group in ipairs(admin_groups) do
            for _, api_backend in ipairs(api_backends) do
              if api_backend.id == admin_group["_api_backend_id"] then
                api_backend["_api_backend_id"] = nil
                table.insert(api_backend["admin_groups"], admin_group)
              end
            end
          end
        end
      end,
    },
  },

  attributes = function(self, options)
    if not options then
      local settings_options = {
        includes = {
          http_headers = {},
          rate_limits = {},
          required_roles = {},
        },
      }
      options = {
        includes = {
          rewrites = {},
          servers = {},
          settings = settings_options,
          sub_settings = {
            includes = {
              settings = settings_options,
            },
          },
          url_matches = {},
        },
      }
    end

    return model_ext.record_attributes(self, options)
  end,

  authorize = function(self)
    api_backend_policy.authorize_show(ngx.ctx.current_admin, self:attributes())
  end,

  url_match_frontend_prefixes = function(self)
    local url_match_frontend_prefixes = {}
    for _, url_match in ipairs(self:get_url_matches()) do
      table.insert(url_match_frontend_prefixes, url_match.frontend_prefix)
    end

    return url_match_frontend_prefixes
  end,

  api_scopes_as_json = function(self)
    local api_scopes = {}
    for _, api_scope in ipairs(self:get_api_scopes()) do
      table.insert(api_scopes, api_scope:embedded_json())
    end

    return api_scopes
  end,

  api_scope_names = function(self)
    local api_scope_names = {}
    for _, api_scope in ipairs(self:get_api_scopes()) do
      table.insert(api_scope_names, api_scope.name)
    end

    return api_scope_names
  end,

  root_api_scope_as_json = function(self)
    local root_api_scope = self:get_root_api_scope()
    if root_api_scope then
      return root_api_scope:embedded_json()
    else
      return nil
    end
  end,

  root_api_scope_name = function(self)
    local root_api_scope = self:get_root_api_scope()
    if root_api_scope then
      return root_api_scope.name
    else
      return nil
    end
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

  as_json = function(self, options)
    local data = {
      id = json_null_default(self.id),
      name = json_null_default(self.name),
      backend_protocol = json_null_default(self.backend_protocol),
      frontend_host = json_null_default(self.frontend_host),
      backend_host = json_null_default(self.backend_host),
      balance_algorithm = json_null_default(self.balance_algorithm),
      keepalive_connections = json_null_default(self.keepalive_connections),
      frontend_prefixes = {},
      rewrites = {},
      servers = {},
      settings = json_null,
      sub_settings = {},
      url_matches = {},
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

    local rewrites = self:get_rewrites()
    for _, rewrite in ipairs(rewrites) do
      table.insert(data["rewrites"], rewrite:as_json(options))
    end

    local servers = self:get_servers()
    for _, server in ipairs(servers) do
      table.insert(data["servers"], server:as_json(options))
    end

    local sub_settings = self:get_sub_settings()
    for _, sub_setting in ipairs(sub_settings) do
      table.insert(data["sub_settings"], sub_setting:as_json(options))
    end

    local url_matches = self:get_url_matches()
    for _, url_match in ipairs(url_matches) do
      table.insert(data["url_matches"], url_match:as_json(options))
      table.insert(data["frontend_prefixes"], url_match.frontend_prefix)
    end
    data["frontend_prefixes"] = table.concat(data["frontend_prefixes"], ", ")

    local settings = self:get_settings()
    if settings then
      data["settings"] = settings:as_json(options)
    end

    json_array_fields(data, {
      "rewrites",
      "servers",
      "sub_settings",
      "url_matches",
    }, options)

    if ngx.ctx.current_admin.superuser then
      data["organization_name"] = json_null_default(self.organization_name)
      data["status_description"] = json_null_default(self.status_description)
      data["api_scopes"] = json_null_default(self:api_scopes_as_json())
      data["root_api_scope"] = json_null_default(self:root_api_scope_as_json())
      data["admin_groups"] = json_null_default(self:admin_groups_as_json())

      json_array_fields(data, {
        "api_scopes",
        "admin_groups",
      }, options)
    end

    if options and options["for_publishing"] then
      data["organization_name"] = nil
      data["status_description"] = nil
      data["admin_groups"] = nil
      data["api_scopes"] = nil
      data["frontend_prefixes"] = nil
      data["root_api_scope"] = nil
    end

    return data
  end,

  embedded_json = function(self)
    return {
      id = json_null_default(self.id),
      name = json_null_default(self.name),
    }
  end,

  csv_headers = function()
    local headers = {
      t("Name"),
      t("Host"),
      t("Prefixes"),
    }

    if ngx.ctx.current_admin.superuser then
      table.insert(headers, t("Organization Name"))
      table.insert(headers, t("Status"))
      table.insert(headers, t("Root API Scope"))
      table.insert(headers, t("API Scopes"))
      table.insert(headers, t("Admin Groups"))
    end

    return headers
  end,

  as_csv = function(self)
    local data = {
      json_null_default(self.name),
      json_null_default(self.frontend_host),
      json_null_default(table.concat(self:url_match_frontend_prefixes(), "\n")),
    }

    if ngx.ctx.current_admin.superuser then
      table.insert(data, json_null_default(self.organization_name))
      table.insert(data, json_null_default(self.status_description))
      table.insert(data, json_null_default(self:root_api_scope_name()))
      table.insert(data, json_null_default(table.concat(self:api_scope_names(), "\n")))
      table.insert(data, json_null_default(table.concat(self:admin_group_names(), "\n")))
    end

    return data
  end,

  rewrites_update_or_create = function(self, rewrite_values)
    return model_ext.has_many_update_or_create(self, ApiBackendRewrite, "api_backend_id", rewrite_values)
  end,

  rewrites_delete_except = function(self, keep_rewrite_ids)
    return model_ext.has_many_delete_except(self, ApiBackendRewrite, "api_backend_id", keep_rewrite_ids)
  end,

  servers_update_or_create = function(self, server_values)
    return model_ext.has_many_update_or_create(self, ApiBackendServer, "api_backend_id", server_values)
  end,

  servers_delete_except = function(self, keep_server_ids)
    return model_ext.has_many_delete_except(self, ApiBackendServer, "api_backend_id", keep_server_ids)
  end,

  settings_update_or_create = function(self, settings_values)
    return model_ext.has_one_update_or_create(self, ApiBackendSettings, "api_backend_id", settings_values)
  end,

  settings_delete = function(self)
    return model_ext.has_one_delete(self, ApiBackendSettings, "api_backend_id")
  end,

  sub_settings_update_or_create = function(self, sub_settings_values)
    return model_ext.has_many_update_or_create(self, ApiBackendSubUrlSettings, "api_backend_id", sub_settings_values)
  end,

  sub_settings_delete_except = function(self, keep_sub_settings_ids)
    return model_ext.has_many_delete_except(self, ApiBackendSubUrlSettings, "api_backend_id", keep_sub_settings_ids)
  end,

  url_matches_update_or_create = function(self, url_match_values)
    return model_ext.has_many_update_or_create(self, ApiBackendUrlMatch, "api_backend_id", url_match_values)
  end,

  url_matches_delete_except = function(self, keep_url_match_ids)
    return model_ext.has_many_delete_except(self, ApiBackendUrlMatch, "api_backend_id", keep_url_match_ids)
  end,
}, {
  authorize = function(data)
    api_backend_policy.authorize_modify(ngx.ctx.current_admin, data)
  end,

  before_validate = function(_, values)
    add_sort_order_from_array_order(values["rewrites"])
    add_sort_order_from_array_order(values["sub_settings"])
  end,

  validate = function(_, data)
    local errors = {}
    validate_field(errors, data, "name", t("Name"), {
      { validation_ext.string:minlen(1), t("can't be blank") },
      { validation_ext.db_null_optional.string:maxlen(255), string.format(t("is too long (maximum is %d characters)"), 255) },
    })
    validate_field(errors, data, "backend_protocol", t("Backend protocol"), {
      { validation_ext:regex("^(http|https)$", "jo"), t("is not included in the list") },
    })
    validate_field(errors, data, "frontend_host", t("Frontend host"), {
      { validation_ext.string:minlen(1), t("can't be blank") },
      { validation_ext.db_null_optional.string:maxlen(255), string.format(t("is too long (maximum is %d characters)"), 255) },
      { validation_ext.db_null_optional:regex(common_validations.host_format_with_wildcard, "jo"), t('must be in the format of "example.com"') },
    })
    if not data["frontend_host"] or string.sub(data["frontend_host"], 1, 1) ~= "*" then
      validate_field(errors, data, "backend_host", t("Backend host"), {
        { validation_ext.string:minlen(1), t("can't be blank") },
        { validation_ext.db_null_optional.string:maxlen(255), string.format(t("is too long (maximum is %d characters)"), 255) },
      })
    end
    if data["backend_host"] and data["backend_host"] ~= db_null then
      validate_field(errors, data, "backend_host", t("Backend host"), {
        { validation_ext.db_null_optional:regex(common_validations.host_format_with_wildcard, "jo"), t('must be in the format of "example.com"') },
      })
    end
    validate_field(errors, data, "balance_algorithm", t("Balance algorithm"), {
      { validation_ext:regex("^(round_robin|least_conn|ip_hash)$", "jo"), t("is not included in the list") },
    })
    validate_field(errors, data, "keepalive_connections", t("Keepalive connections"), {
      { validation_ext.db_null_optional.tonumber.number:between(0, 32767), t("is not a number") },
    })
    validate_field(errors, data, "servers", t("Servers"), {
      { validation_ext.non_null_table:minlen(1), t("Must have at least one servers") },
    }, { error_field = "base" })
    validate_field(errors, data, "url_matches", t("URL matches"), {
      { validation_ext.non_null_table:minlen(1), t("Must have at least one url_matches") },
    }, { error_field = "base" })
    validate_field(errors, data, "organization_name", t("Organization Name"), {
      { validation_ext.db_null_optional.string:maxlen(255), string.format(t("is too long (maximum is %d characters)"), 255) },
    })
    validate_field(errors, data, "status_description", t("Status"), {
      { validation_ext.db_null_optional.string:maxlen(255), string.format(t("is too long (maximum is %d characters)"), 255) },
    })
    validate_relation_uniqueness(errors, data, "servers", "host", t("Host"), {
      "api_backend_id",
      "host",
      "port",
    })
    validate_relation_uniqueness(errors, data, "url_matches", "frontend_prefix", t("Frontend prefix"), {
      "api_backend_id",
      "frontend_prefix",
    })
    validate_relation_uniqueness(errors, data, "sub_settings", "regex", t("Regex"), {
      "api_backend_id",
      "http_method",
      "regex",
    })
    validate_relation_uniqueness(errors, data, "sub_settings", "sort_order", t("Sort order"), {
      "api_backend_id",
      "sort_order",
    })
    validate_relation_uniqueness(errors, data, "rewrites", "frontend_matcher", t("Frontend matcher"), {
      "api_backend_id",
      "matcher_type",
      "http_method",
      "frontend_matcher",
    })
    validate_relation_uniqueness(errors, data, "rewrites", "sort_order", t("Sort order"), {
      "api_backend_id",
      "sort_order",
    })
    return errors
  end,

  after_save = function(self, values)
    model_ext.has_many_save(self, values, "rewrites")
    model_ext.has_many_save(self, values, "servers")
    model_ext.has_many_save(self, values, "sub_settings")
    model_ext.has_many_save(self, values, "url_matches")
    model_ext.has_one_save(self, values, "settings")
  end,
})

ApiBackend.all_sorted = function(where)
  local sql = ""
  if where then
    sql = sql .. "WHERE " .. where
  end
  sql = sql .. " ORDER BY name"

  return ApiBackend:select(sql)
end

ApiBackend.preload_for_as_json = function(current_admin)
  local preload = {
    "rewrites",
    "servers",
    "url_matches",
    settings = {
      "http_headers",
      "rate_limits",
      "required_roles",
    },
    sub_settings = {
      settings = {
        "http_headers",
        "rate_limits",
        "required_roles",
      },
    },
  }

  if current_admin.superuser then
    table.insert(preload, "api_scopes")
    table.insert(preload, "root_api_scope")
    table.insert(preload, "admin_groups")
  end

  return preload
end

return ApiBackend
