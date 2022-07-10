local ApiBackend = require "api-umbrella.web-app.models.api_backend"
local api_backend_policy = require "api-umbrella.web-app.policies.api_backend_policy"
local capture_errors_json = require("api-umbrella.web-app.utils.capture_errors").json
local csrf_validate_token_or_admin_token_filter = require("api-umbrella.web-app.utils.csrf").validate_token_or_admin_token_filter
local datatables = require "api-umbrella.web-app.utils.datatables"
local db = require "lapis.db"
local dbify_json_nulls = require "api-umbrella.web-app.utils.dbify_json_nulls"
local deep_merge_overwrite_arrays = require "api-umbrella.utils.deep_merge_overwrite_arrays"
local is_array = require "api-umbrella.utils.is_array"
local is_empty = require "api-umbrella.utils.is_empty"
local is_hash = require "api-umbrella.utils.is_hash"
local json_response = require "api-umbrella.web-app.utils.json_response"
local require_admin = require "api-umbrella.web-app.utils.require_admin"
local respond_to = require "api-umbrella.web-app.utils.respond_to"
local validation_ext = require "api-umbrella.web-app.utils.validation_ext"
local wrapped_json_params = require "api-umbrella.web-app.utils.wrapped_json_params"

local db_null = db.NULL

local _M = {}

function _M.index(self)
  local options = {
    where = {
      api_backend_policy.authorized_query_scope(self.current_admin),
    },
    search_joins = {
      "LEFT JOIN api_backend_servers ON api_backends.id = api_backend_servers.api_backend_id",
      "LEFT JOIN api_backend_url_matches ON api_backends.id = api_backend_url_matches.api_backend_id",
    },
    search_fields = {
      db.raw("api_backends.name"),
      db.raw("api_backends.frontend_host"),
      db.raw("api_backends.backend_host"),
      db.raw("api_backend_servers.host"),
      db.raw("api_backend_url_matches.backend_prefix"),
      db.raw("api_backend_url_matches.frontend_prefix"),
    },
    order_joins = {
      ["root_api_scope.name"] = " CROSS JOIN LATERAL (" ..
        " SELECT api_scopes.*" ..
        " FROM api_scopes" ..
        " INNER JOIN api_backend_url_matches ON api_backends.id = api_backend_url_matches.api_backend_id AND api_backend_url_matches.frontend_prefix LIKE api_scopes.path_prefix || '%' " ..
        " WHERE api_scopes.host = api_backends.frontend_host" ..
        " ORDER BY length(api_scopes.path_prefix)" ..
        " LIMIT 1" ..
        ") AS root_api_scope",
    },
    order_fields = {
      "name",
      "frontend_host",
      "created_at",
      "updated_at",
    },
    preload = {
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
    },
    csv_filename = "apis",
  }

  if self.current_admin.superuser then
    table.insert(options["search_joins"], "LEFT JOIN api_scopes ON api_backends.frontend_host = api_scopes.host AND api_backend_url_matches.frontend_prefix LIKE api_scopes.path_prefix || '%'")
    table.insert(options["search_joins"], "LEFT JOIN admin_groups_api_scopes ON api_scopes.id = admin_groups_api_scopes.api_scope_id")
    table.insert(options["search_joins"], "LEFT JOIN admin_groups ON admin_groups_api_scopes.admin_group_id = admin_groups.id")

    table.insert(options["search_fields"], db.raw("api_backends.organization_name"))
    table.insert(options["search_fields"], db.raw("api_backends.status_description"))
    table.insert(options["search_fields"], db.raw("api_scopes.name"))
    table.insert(options["search_fields"], db.raw("admin_groups.name"))

    table.insert(options["order_fields"], "organization_name")
    table.insert(options["order_fields"], "status_description")
    table.insert(options["order_fields"], "root_api_scope.name")

    table.insert(options["preload"], "api_scopes")
    table.insert(options["preload"], "root_api_scope")
    table.insert(options["preload"], "admin_groups")
  end

  return datatables.index(self, ApiBackend, options)
end

function _M.show(self)
  self.api_backend:authorize()
  local response = {
    api = self.api_backend:as_json(),
  }

  return json_response(self, response)
end

function _M.create(self)
  local api_backend = assert(ApiBackend:authorized_create(_M.api_backend_params(self)))
  local response = {
    api = api_backend:as_json(),
  }

  self.res.status = 201
  return json_response(self, response)
end

function _M.update(self)
  self.api_backend:authorized_update(_M.api_backend_params(self))

  return { status = 204, layout = false }
end

function _M.destroy(self)
  assert(self.api_backend:authorized_delete())

  return { status = 204, layout = false }
end

function _M.move_after(self)
  self.api_backend:authorize()
  if self.params and not is_empty(self.params["move_after_id"]) then
    local after_api
    local ok = validation_ext.string.uuid(self.params["move_after_id"])
    if ok then
      after_api = ApiBackend:find(self.params["move_after_id"])
    end
    if after_api then
      after_api:authorize()
      self.api_backend:move_after(after_api)
    end
  else
    self.api_backend:move_to_beginning()
  end

  return { status = 204, layout = false }
end

local function api_backend_settings_params(input_settings)
  if not input_settings then
    return nil
  end

  if not is_hash(input_settings) then
    return db_null
  end

  local params_settings = dbify_json_nulls({
    id = input_settings["id"],
    allowed_ips = input_settings["allowed_ips"],
    allowed_referers = input_settings["allowed_referers"],
    anonymous_rate_limit_behavior = input_settings["anonymous_rate_limit_behavior"],
    api_key_verification_level = input_settings["api_key_verification_level"],
    api_key_verification_transition_start_at = input_settings["api_key_verification_transition_start_at"],
    append_query_string = input_settings["append_query_string"],
    authenticated_rate_limit_behavior = input_settings["authenticated_rate_limit_behavior"],
    default_response_headers_string = input_settings["default_response_headers_string"],
    disable_api_key = input_settings["disable_api_key"],
    headers_string = input_settings["headers_string"],
    http_basic_auth = input_settings["http_basic_auth"],
    override_response_headers_string = input_settings["override_response_headers_string"],
    pass_api_key_header = input_settings["pass_api_key_header"],
    pass_api_key_query_param = input_settings["pass_api_key_query_param"],
    rate_limit_bucket_name = input_settings["rate_limit_bucket_name"],
    rate_limit_mode = input_settings["rate_limit_mode"],
    redirect_https = input_settings["redirect_https"],
    require_https = input_settings["require_https"],
    require_https_transition_start_at = input_settings["require_https_transition_start_at"],
    required_role_ids = input_settings["required_roles"],
    required_roles_override = input_settings["required_roles_override"],
  })

  local error_data_param_fields = {
    "error_data",
    "error_data_yaml_strings",
  }
  local error_data_fields = {
    "common",
    "api_key_missing",
    "api_key_invalid",
    "api_key_disabled",
    "api_key_unauthorized",
    "over_rate_limit",
    "https_required",
  }
  for _, param_field in ipairs(error_data_param_fields) do
    if input_settings[param_field] then
      params_settings[param_field] = {}
      if is_hash(input_settings[param_field]) then
        for _, error_data_field in ipairs(error_data_fields) do
          local input_value = input_settings[param_field][error_data_field]
          params_settings[param_field][error_data_field] = input_value
        end
      end
    end
  end

  if input_settings["error_templates"] then
    params_settings["error_templates"] = {}
    if is_hash(input_settings["error_templates"]) then
      local error_template_fields = {
        "csv",
        "html",
        "json",
        "xml",
      }
      for _, error_template_field in ipairs(error_template_fields) do
        local input_value = input_settings["error_templates"][error_template_field]
        params_settings["error_templates"][error_template_field] = input_value
      end
    end
  end

  local header_fields = {
    "default_response_headers",
    "headers",
    "override_response_headers",
  }
  for _, header_field in ipairs(header_fields) do
    if input_settings[header_field] then
      params_settings[header_field] = {}
      if is_array(input_settings[header_field]) then
        for _, input_header in ipairs(input_settings[header_field]) do
          table.insert(params_settings[header_field], dbify_json_nulls({
            id = input_header["id"],
            key = input_header["key"],
            value = input_header["value"],
          }))
        end
      end
    end
  end

  if input_settings["rate_limits"] then
    params_settings["rate_limits"] = {}
    if is_array(input_settings["rate_limits"]) then
      for _, input_rate_limit in ipairs(input_settings["rate_limits"]) do
        table.insert(params_settings["rate_limits"], dbify_json_nulls({
          id = input_rate_limit["id"],
          duration = input_rate_limit["duration"],
          limit_by = input_rate_limit["limit_by"],
          limit_to = input_rate_limit["limit_to"] or input_rate_limit["limit"],
          distributed = input_rate_limit["distributed"],
          response_headers = input_rate_limit["response_headers"],
        }))
      end
    end
  end

  return params_settings
end

function _M.api_backend_params(self)
  local params = {}
  if self.params and type(self.params["api"]) == "table" then
    local input = self.params["api"]
    params = dbify_json_nulls({
      name = input["name"],
      backend_protocol = input["backend_protocol"],
      frontend_host = input["frontend_host"],
      backend_host = input["backend_host"],
      balance_algorithm = input["balance_algorithm"],
      keepalive_connections = input["keepalive_connections"],
    })

    if input["rewrites"] then
      params["rewrites"] = {}
      if is_array(input["rewrites"]) then
        for _, input_rewrite in ipairs(input["rewrites"]) do
          table.insert(params["rewrites"], dbify_json_nulls({
            id = input_rewrite["id"],
            matcher_type = input_rewrite["matcher_type"],
            http_method = input_rewrite["http_method"],
            frontend_matcher = input_rewrite["frontend_matcher"],
            backend_replacement = input_rewrite["backend_replacement"],
            sort_order = input_rewrite["sort_order"],
          }))
        end
      end
    end

    if input["servers"] then
      params["servers"] = {}
      if is_array(input["servers"]) then
        for _, input_server in ipairs(input["servers"]) do
          table.insert(params["servers"], dbify_json_nulls({
            id = input_server["id"],
            host = input_server["host"],
            port = input_server["port"],
          }))
        end
      end
    end

    if input["url_matches"] then
      params["url_matches"] = {}
      if is_array(input["url_matches"]) then
        for _, input_url_match in ipairs(input["url_matches"]) do
          table.insert(params["url_matches"], dbify_json_nulls({
            id = input_url_match["id"],
            frontend_prefix = input_url_match["frontend_prefix"],
            backend_prefix = input_url_match["backend_prefix"],
          }))
        end
      end
    end

    if input["sub_settings"] then
      params["sub_settings"] = {}
      if is_array(input["sub_settings"]) then
        for _, input_sub_settings in ipairs(input["sub_settings"]) do
          table.insert(params["sub_settings"], dbify_json_nulls({
            id = input_sub_settings["id"],
            http_method = input_sub_settings["http_method"],
            regex = input_sub_settings["regex"],
            settings = api_backend_settings_params(input_sub_settings["settings"]),
            sort_order = input_sub_settings["sort_order"],
          }))
        end
      end
    end

    if input["settings"] then
      params["settings"] = api_backend_settings_params(input["settings"])
    end

    if self.current_admin.superuser then
      deep_merge_overwrite_arrays(params, dbify_json_nulls({
        organization_name = input["organization_name"],
        status_description = input["status_description"],
      }))
    end
  end

  return params
end

return function(app)
  local function find_api_backend(self)
    local ok = validation_ext.string.uuid(self.params["id"])
    if ok then
      self.api_backend = ApiBackend:find(self.params["id"])
    end
    if not self.api_backend then
      return self.app.handle_404(self)
    end
  end

  app:match("/api-umbrella/v1/apis/:id(.:format)", respond_to({
    before = require_admin(find_api_backend),
    GET = capture_errors_json(_M.show),
    POST = csrf_validate_token_or_admin_token_filter(capture_errors_json(wrapped_json_params(_M.update, "api"))),
    PUT = csrf_validate_token_or_admin_token_filter(capture_errors_json(wrapped_json_params(_M.update, "api"))),
    DELETE = csrf_validate_token_or_admin_token_filter(capture_errors_json(_M.destroy)),
  }))

  app:match("/api-umbrella/v1/apis/:id/move_after(.:format)", respond_to({
    before = require_admin(find_api_backend),
    PUT = csrf_validate_token_or_admin_token_filter(capture_errors_json(wrapped_json_params(_M.move_after, "api"))),
  }))

  app:match("/api-umbrella/v1/apis(.:format)", respond_to({
    before = require_admin(),
    GET = capture_errors_json(_M.index),
    POST = csrf_validate_token_or_admin_token_filter(capture_errors_json(wrapped_json_params(_M.create, "api"))),
  }))
end
