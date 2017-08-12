local ApiBackendRewrite = require "api-umbrella.lapis.models.api_backend_rewrite"
local ApiBackendServer = require "api-umbrella.lapis.models.api_backend_server"
local ApiBackendUrlMatch = require "api-umbrella.lapis.models.api_backend_url_match"
local cjson = require "cjson"
local common_validations = require "api-umbrella.utils.common_validations"
local db = require "lapis.db"
local is_array = require "api-umbrella.utils.is_array"
local is_empty = require("pl.types").is_empty
local iso8601 = require "api-umbrella.utils.iso8601"
local model_ext = require "api-umbrella.utils.model_ext"
local t = require("resty.gettext").gettext
local validation = require "resty.validation"

local json_null = cjson.null
local validate_field = model_ext.validate_field

local function update_or_create_has_many(self, relation_model, relation_values)
  relation_values["api_backend_id"] = assert(self.id)

  local relation_record
  if relation_values["id"] then
    relation_record = relation_model:find({
      api_backend_id = relation_values["api_backend_id"],
      id = relation_values["id"],
    })
    assert(relation_record:update(relation_values))
  else
    relation_record = assert(relation_model:create(relation_values))
  end

  return relation_record
end

local function delete_has_many_except(self, relation_model, keep_ids)
  local table_name = assert(relation_model:table_name())
  local api_backend_id = assert(self.id)

  if is_empty(keep_ids) then
    db.delete(table_name, "api_backend_id = ?", api_backend_id)
  else
    db.delete(table_name, "api_backend_id = ? AND id NOT IN ?", api_backend_id, db.list(keep_ids))
  end
end

local ApiBackend = model_ext.new_class("api_backends", {
  relations = {
    { "rewrites", has_many = "ApiBackendRewrite" },
    { "servers", has_many = "ApiBackendServer" },
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

    local url_matches = self:get_url_matches()
    for _, url_match in ipairs(url_matches) do
      table.insert(data["url_matches"], url_match:as_json())
      table.insert(data["frontend_prefixes"], url_match.frontend_prefix)
    end
    setmetatable(data["url_matches"], cjson.empty_array_mt)

    data["frontend_prefixes"] = table.concat(data["frontend_prefixes"], ", ")

    return data
  end,

  update_or_create_rewrite = function(self, rewrite_values)
    return update_or_create_has_many(self, ApiBackendRewrite, rewrite_values)
  end,

  update_or_create_server = function(self, server_values)
    return update_or_create_has_many(self, ApiBackendServer, server_values)
  end,

  update_or_create_url_match = function(self, url_match_values)
    return update_or_create_has_many(self, ApiBackendUrlMatch, url_match_values)
  end,

  delete_rewrites_except = function(self, keep_rewrite_ids)
    return delete_has_many_except(self, ApiBackendRewrite, keep_rewrite_ids)
  end,

  delete_servers_except = function(self, keep_server_ids)
    return delete_has_many_except(self, ApiBackendServer, keep_server_ids)
  end,

  delete_url_matches_except = function(self, keep_url_match_ids)
    return delete_has_many_except(self, ApiBackendUrlMatch, keep_url_match_ids)
  end,
}, {
  before_validate_on_create = function(_, values)
    values["sort_order"] = 0
  end,

  validate = function(_, values)
    local errors = {}
    validate_field(errors, values, "name", validation.string:minlen(1), t("can't be blank"))
    validate_field(errors, values, "sort_order", validation.number, t("can't be blank"))
    validate_field(errors, values, "backend_protocol", validation:regex("^(http|https)$", "jo"), t("is not included in the list"))
    validate_field(errors, values, "frontend_host", validation.string:minlen(1), t("can't be blank"))
    validate_field(errors, values, "frontend_host", validation.optional:regex(common_validations.host_format_with_wildcard, "jo"), t('must be in the format of "example.com"'))
    if not values["frontend_host"] or string.sub(values["frontend_host"], 1, 1) ~= "*" then
      validate_field(errors, values, "backend_host", validation.string:minlen(1), t("can't be blank"))
      validate_field(errors, values, "backend_host", validation.optional:regex(common_validations.host_format_with_wildcard, "jo"), t('must be in the format of "example.com"'))
    end
    validate_field(errors, values, "balance_algorithm", validation:regex("^(round_robin|least_conn|ip_hash)$", "jo"), t("is not included in the list"))
    validate_field(errors, values, "servers", validation.table:minlen(1), t("can't be blank"))
    validate_field(errors, values, "url_matches", validation.table:minlen(1), t("can't be blank"))
    return errors
  end,

  after_save = function(self, values)
    if is_array(values["rewrites"]) then
      local rewrite_ids = {}
      for _, rewrite_values in ipairs(values["rewrites"]) do
        local rewrite = self:update_or_create_rewrite(rewrite_values)
        table.insert(rewrite_ids, assert(rewrite.id))
      end
      self:delete_rewrites_except(rewrite_ids)
    end

    if is_array(values["servers"]) then
      local server_ids = {}
      for _, server_values in ipairs(values["servers"]) do
        local server = self:update_or_create_server(server_values)
        table.insert(server_ids, assert(server.id))
      end
      self:delete_servers_except(server_ids)
    end

    if is_array(values["url_matches"]) then
      local url_match_ids = {}
      for _, url_match_values in ipairs(values["url_matches"]) do
        local url_match = self:update_or_create_url_match(url_match_values)
        table.insert(url_match_ids, assert(url_match.id))
      end
      self:delete_url_matches_except(url_match_ids)
    end
  end,
})

return ApiBackend
