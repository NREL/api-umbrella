local ApiBackendRewrite = require "api-umbrella.lapis.models.api_backend_rewrite"
local ApiBackendServer = require "api-umbrella.lapis.models.api_backend_server"
local ApiBackendSettings = require "api-umbrella.lapis.models.api_backend_settings"
local ApiBackendSubUrlSettings = require "api-umbrella.lapis.models.api_backend_sub_url_settings"
local ApiBackendUrlMatch = require "api-umbrella.lapis.models.api_backend_url_match"
local cjson = require "cjson"
local common_validations = require "api-umbrella.utils.common_validations"
local db = require "lapis.db"
local iso8601 = require "api-umbrella.utils.iso8601"
local model_ext = require "api-umbrella.utils.model_ext"
local t = require("resty.gettext").gettext
local validation = require "resty.validation"

local db_null = db.NULL
local json_null = cjson.null
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

local ApiBackend
ApiBackend = model_ext.new_class("api_backends", {
  relations = {
    { "rewrites", has_many = "ApiBackendRewrite" },
    { "servers", has_many = "ApiBackendServer" },
    { "settings", has_one = "ApiBackendSettings" },
    { "sub_settings", has_many = "ApiBackendSubUrlSettings" },
    { "url_matches", has_many = "ApiBackendUrlMatch" },
  },

  as_json = function(self)
    local data = {
      id = self.id or json_null,
      name = self.name or json_null,
      sort_order = self.sort_order or json_null,
      backend_protocol = self.backend_protocol or json_null,
      frontend_host = self.frontend_host or json_null,
      backend_host = self.backend_host or json_null,
      balance_algorithm = self.balance_algorithm or json_null,
      frontend_prefixes = {},
      rewrites = {},
      servers = {},
      settings = json_null,
      sub_settings = {},
      url_matches = {},
      created_at = iso8601.format_postgres(self.created_at) or json_null,
      created_by = self.created_by or json_null,
      updated_at = iso8601.format_postgres(self.updated_at) or json_null,
      updated_by = self.updated_by or json_null,
      deleted_at = json_null,
      version = 1,
    }

    local rewrites = self:get_rewrites()
    for _, rewrite in ipairs(rewrites) do
      table.insert(data["rewrites"], rewrite:as_json())
    end
    setmetatable(data["rewrites"], cjson.empty_array_mt)

    local servers = self:get_servers()
    for _, server in ipairs(servers) do
      table.insert(data["servers"], server:as_json())
    end
    setmetatable(data["servers"], cjson.empty_array_mt)

    local sub_settings = self:get_sub_settings()
    for _, sub_setting in ipairs(sub_settings) do
      table.insert(data["sub_settings"], sub_setting:as_json())
    end
    setmetatable(data["sub_settings"], cjson.empty_array_mt)

    local url_matches = self:get_url_matches()
    for _, url_match in ipairs(url_matches) do
      table.insert(data["url_matches"], url_match:as_json())
      table.insert(data["frontend_prefixes"], url_match.frontend_prefix)
    end
    setmetatable(data["url_matches"], cjson.empty_array_mt)
    data["frontend_prefixes"] = table.concat(data["frontend_prefixes"], ", ")

    local settings = self:get_settings()
    if settings then
      data["settings"] = settings:as_json()
    end

    return data
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
        db.update(ApiBackend:table_name(), { sort_order = api.sort_order }, { id = api.id })
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
  before_validate_on_create = function(_, values)
    if not values["sort_order"] or values["sort_order"] == db_null then
      values["sort_order"] = get_new_end_sort_order()
    end
  end,

  validate = function(_, data)
    local errors = {}
    validate_field(errors, data, "name", validation.string:minlen(1), t("can't be blank"))
    validate_field(errors, data, "sort_order", validation.number, t("can't be blank"))
    validate_field(errors, data, "backend_protocol", validation:regex("^(http|https)$", "jo"), t("is not included in the list"))
    validate_field(errors, data, "frontend_host", validation.string:minlen(1), t("can't be blank"))
    validate_field(errors, data, "frontend_host", validation.optional:regex(common_validations.host_format_with_wildcard, "jo"), t('must be in the format of "example.com"'))
    if not data["frontend_host"] or string.sub(data["frontend_host"], 1, 1) ~= "*" then
      validate_field(errors, data, "backend_host", validation.string:minlen(1), t("can't be blank"))
    end
    if data["backend_host"] and data["backend_host"] ~= db_null then
      validate_field(errors, data, "backend_host", validation.optional:regex(common_validations.host_format_with_wildcard, "jo"), t('must be in the format of "example.com"'))
    end
    validate_field(errors, data, "balance_algorithm", validation:regex("^(round_robin|least_conn|ip_hash)$", "jo"), t("is not included in the list"))
    validate_field(errors, data, "servers", validation.table:minlen(1), t("must have at least one servers"), { error_field = "base" })
    validate_field(errors, data, "url_matches", validation.table:minlen(1), t("must have at least one url_matches"), { error_field = "base" })
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

return ApiBackend
