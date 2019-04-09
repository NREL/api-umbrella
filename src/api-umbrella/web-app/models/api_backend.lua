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

local MAX_SORT_ORDER = 2147483647
local MIN_SORT_ORDER = -2147483648
local SORT_ORDER_GAP = 10000

local function get_new_beginning_sort_order()
  local new_order = 0

  -- Find the current first sort_order value and move this record SORT_ORDER_GAP before that value.
  local res = db.query("SELECT MIN(sort_order) AS current_min FROM api_backends")
  if res and res[1] and res[1]["current_min"] then
    local current_min = res[1]["current_min"]
    new_order = current_min - SORT_ORDER_GAP

    -- If we've hit the minimum allowed value, find an new minimum value in
    -- between.
    if new_order < MIN_SORT_ORDER then
      new_order = math.floor((current_min + MIN_SORT_ORDER) / 2.0)
    end
  end

  return new_order
end

local function get_new_end_sort_order()
  local new_order = 0

  -- Find the current first sort_order value and move this record
  -- SORT_ORDER_GAP after that value.
  local res = db.query("SELECT MAX(sort_order) AS current_max FROM api_backends")
  if res and res[1] and res[1]["current_max"] then
    local current_max = res[1]["current_max"]
    new_order = current_max + SORT_ORDER_GAP

    -- If we've hit the maximum allowed value, find an new maximum value in
    -- between.
    if new_order > MAX_SORT_ORDER then
      new_order = math.ceil((current_max + MAX_SORT_ORDER) / 2.0)
    end
  end

  return new_order
end

local function add_sort_order_from_array_order(array)
  if is_array(array) and array ~= db_null then
    for index, values in ipairs(array) do
      values["sort_order"] = index
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
      order = "sort_order",
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

  api_scopes_as_json = function(self)
    local api_scopes = {}
    for _, api_scope in ipairs(self:get_api_scopes()) do
      table.insert(api_scopes, api_scope:embedded_json())
    end

    return api_scopes
  end,

  root_api_scope_as_json = function(self)
    local root_api_scope = self:get_root_api_scope()
    if root_api_scope then
      return root_api_scope:embedded_json()
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

  as_json = function(self, options)
    local data = {
      id = json_null_default(self.id),
      name = json_null_default(self.name),
      sort_order = json_null_default(self.sort_order),
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

  move_to_beginning = function(self)
    local order = get_new_beginning_sort_order()
    self:update({ sort_order = order })
  end,

  move_after = function(self, after_api)
    local order
    local after_after_api = ApiBackend:select("WHERE id != ? AND sort_order > ? ORDER BY sort_order ASC LIMIT 1", self.id, after_api.sort_order)[1]
    if after_after_api then
      if after_api.sort_order and after_after_api.sort_order then
        order = ((after_api.sort_order + after_after_api.sort_order) / 2.0)
        if order < 0 then
          order = math.ceil(order)
        else
          order = math.floor(order)
        end
      end
    else
      if after_api.sort_order then
        order = after_api.sort_order + SORT_ORDER_GAP
      end
    end

    if order then
      if order > MAX_SORT_ORDER then
        order = math.ceil((after_api.sort_order + MAX_SORT_ORDER) / 2.0)
      elseif order < MIN_SORT_ORDER then
        order = math.floor((after_api.sort_order + MIN_SORT_ORDER) / 2.0)
      end
    end

    self:update({ sort_order = order })
  end,

  ensure_unique_sort_order = function(self, original_order)
    -- Look for any existing records that have conflicting sort_order values.
    -- We will then shift those existing sort_order values to be unique.
    --
    -- Note: This iterative, recursive approach isn't efficient, but since our
    -- whole approach of having SORT_ORDER_GAP between each sort_order value,
    -- conflicts like this should be exceedingly rare.
    local conflicting_order_apis = ApiBackend:select("WHERE id != ? AND sort_order = ?", self.id, self.sort_order)
    if conflicting_order_apis and #conflicting_order_apis > 0 then
      for index, api in ipairs(conflicting_order_apis) do
        -- Shift positive rank_orders negatively, and negative rank_orders
        -- positively. This is designed so that we work away from the
        -- MAX_SORT_ORDER or MIN_SORT_ORDER values if we're bumping into our
        -- integer size limits.
        --
        -- Base this positive and negative logic on the original sort_order
        -- that triggered this process. This prevents the recursive logic from
        -- getting stuck in infinite loops if based on the current record's
        -- sort_order (since 0 will become -1, which on recursion will become
        -- 0).
        local new_order
        if original_order < 0 then
          new_order = api.sort_order + index
        else
          new_order = api.sort_order - index
        end
        api.sort_order = new_order
        model_ext.transaction_update(ApiBackend:table_name(), { sort_order = api.sort_order }, { id = api.id })
      end

      for _, api in ipairs(conflicting_order_apis) do
        api:ensure_unique_sort_order(original_order)
      end
    end
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
    return model_ext.has_one_delete(self, ApiBackendSettings, "api_backend_id", {})
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

  before_validate_on_create = function(_, values)
    if not values["sort_order"] or values["sort_order"] == db_null then
      values["sort_order"] = get_new_end_sort_order()
    end
  end,

  before_validate = function(_, values)
    add_sort_order_from_array_order(values["rewrites"])
    add_sort_order_from_array_order(values["sub_settings"])
    add_sort_order_from_array_order(values["url_matches"])
  end,

  validate = function(_, data)
    local errors = {}
    validate_field(errors, data, "name", t("Name"), {
      { validation_ext.string:minlen(1), t("can't be blank") },
      { validation_ext.db_null_optional.string:maxlen(255), string.format(t("is too long (maximum is %d characters)"), 255) },
    })
    validate_field(errors, data, "sort_order", t("Sort order"), {
      { validation_ext.tonumber.number, t("can't be blank") },
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
    return errors
  end,

  after_save = function(self, values)
    model_ext.has_many_save(self, values, "rewrites")
    model_ext.has_many_save(self, values, "servers")
    model_ext.has_many_save(self, values, "sub_settings")
    model_ext.has_many_save(self, values, "url_matches")
    model_ext.has_one_save(self, values, "settings")
  end,

  after_commit = function(self)
    self:ensure_unique_sort_order(self.sort_order)
  end,
})

ApiBackend.all_sorted = function(where)
  local sql = ""
  if where then
    sql = sql .. "WHERE " .. where
  end
  sql = sql .. " ORDER BY sort_order"

  return ApiBackend:select(sql)
end

return ApiBackend
