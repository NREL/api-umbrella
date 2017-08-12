local ApiBackendRewrite = require "api-umbrella.lapis.models.api_backend_rewrite"
local ApiBackendServer = require "api-umbrella.lapis.models.api_backend_server"
local ApiBackendUrlMatch = require "api-umbrella.lapis.models.api_backend_url_match"
local cjson = require "cjson"
local is_array = require "api-umbrella.utils.is_array"
local iso8601 = require "api-umbrella.utils.iso8601"
local model_ext = require "api-umbrella.utils.model_ext"
local t = require("resty.gettext").gettext
local validation = require "resty.validation"

local json_null = cjson.null
local validate_field = model_ext.validate_field

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
    rewrite_values["api_backend_id"] = assert(self.id)

    local rewrite
    if rewrite_values["id"] then
      rewrite = ApiBackendRewrite:find({
        api_backend_id = rewrite_values["api_backend_id"],
        id = rewrite_values["id"],
      })
      assert(rewrite:update(rewrite_values))
    else
      rewrite = assert(ApiBackendRewrite:create(rewrite_values))
    end

    return rewrite
  end,

  update_or_create_server = function(self, server_values)
    server_values["api_backend_id"] = assert(self.id)

    local server
    if server_values["id"] then
      server = ApiBackendServer:find({
        api_backend_id = server_values["api_backend_id"],
        id = server_values["id"],
      })
      assert(server:update(server_values))
    else
      server = assert(ApiBackendServer:create(server_values))
    end

    return server
  end,

  update_or_create_url_match = function(self, url_match_values)
    url_match_values["api_backend_id"] = assert(self.id)

    local url_match
    if url_match_values["id"] then
      url_match = ApiBackendUrlMatch:find({
        api_backend_id = url_match_values["api_backend_id"],
        id = url_match_values["id"],
      })
      assert(url_match:update(url_match_values))
    else
      url_match = assert(ApiBackendUrlMatch:create(url_match_values))
    end

    return url_match
  end,
}, {
  before_validate_on_create = function(_, values)
    values["sort_order"] = 0
  end,

  validate = function(_, values)
    local errors = {}
    validate_field(errors, values, "name", validation.string:minlen(1), t("can't be blank"))
    validate_field(errors, values, "sort_order", validation.number, t("can't be blank"))
    validate_field(errors, values, "backend_protocol", validation.string:minlen(1), t("can't be blank"))
    validate_field(errors, values, "frontend_host", validation.string:minlen(1), t("can't be blank"))
    validate_field(errors, values, "backend_host", validation.string:minlen(1), t("can't be blank"))
    validate_field(errors, values, "balance_algorithm", validation.string:minlen(1), t("can't be blank"))
    validate_field(errors, values, "servers", validation.table:minlen(1), t("can't be blank"))
    validate_field(errors, values, "url_matches", validation.table:minlen(1), t("can't be blank"))
    return errors
  end,

  after_save = function(self, values)
    if is_array(values["servers"]) then
      for _, server_values in ipairs(values["servers"]) do
        self:update_or_create_server(server_values)
      end
    end

    if is_array(values["url_matches"]) then
      for _, url_match_values in ipairs(values["url_matches"]) do
        self:update_or_create_url_match(url_match_values)
      end
    end
  end,
})

return ApiBackend
