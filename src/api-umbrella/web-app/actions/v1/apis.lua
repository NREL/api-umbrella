local ApiBackend = require "api-umbrella.web-app.models.api_backend"
local api_backend_policy = require "api-umbrella.web-app.policies.api_backend_policy"
local capture_errors_json = require("api-umbrella.web-app.utils.capture_errors").json
local datatables = require "api-umbrella.web-app.utils.datatables"
local db = require "lapis.db"
local dbify_json_nulls = require "api-umbrella.web-app.utils.dbify_json_nulls"
local is_array = require "api-umbrella.utils.is_array"
local is_empty = require("pl.types").is_empty
local is_hash = require "api-umbrella.utils.is_hash"
local json_params = require("lapis.application").json_params
local json_response = require "api-umbrella.web-app.utils.json_response"
local respond_to = require("lapis.application").respond_to

local db_null = db.NULL

local _M = {}

function _M.index(self)
  return datatables.index(self, ApiBackend, {
    where = {
      api_backend_policy.authorized_query_scope(self.current_admin),
    },
    search_joins = {
      "LEFT JOIN api_backend_servers ON api_backends.id = api_backend_servers.api_backend_id",
      "LEFT JOIN api_backend_url_matches ON api_backends.id = api_backend_url_matches.api_backend_id",
    },
    search_fields = {
      "name",
      "frontend_host",
      "backend_host",
      db.raw("api_backend_servers.host"),
      db.raw("api_backend_url_matches.backend_prefix"),
      db.raw("api_backend_url_matches.frontend_prefix"),
    },
    preload = {
      "rewrites",
      "servers",
      "url_matches",
    },
  })
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

  return { status = 204 }
end

function _M.destroy(self)
  assert(self.api_backend:authorized_delete())

  return { status = 204 }
end

function _M.move_after(self)
  self.api_backend:authorize()
  if self.params and not is_empty(self.params["move_after_id"]) then
    local after_api = ApiBackend:find(self.params["move_after_id"])
    if after_api then
      after_api:authorize()
      self.api_backend:move_after(after_api)
    end
  else
    self.api_backend:move_to_beginning()
  end

  return { status = 204 }
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
    require_https = input_settings["require_https"],
    require_https_transition_start_at = input_settings["require_https_transition_start_at"],
    required_role_ids = input_settings["required_roles"],
    required_roles_override = input_settings["required_roles_override"],
  })

  if input_settings["error_data_yaml_strings"] then
    params_settings["error_data_yaml_strings"] = {}
    if is_hash(input_settings["error_data_yaml_strings"]) then
      local error_data_fields = {
        "common",
        "api_key_missing",
        "api_key_invalid",
        "api_key_disabled",
        "api_key_unauthorized",
        "over_rate_limit",
        "https_required",
      }
      for _, error_data_field in ipairs(error_data_fields) do
        params_settings["error_data_yaml_strings"][error_data_field] = input_settings["error_data_yaml_strings"][error_data_field]
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
          limit_to = input_rate_limit["limit"],
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
  if self.params and self.params["api"] then
    local input = self.params["api"]
    params = dbify_json_nulls({
      name = input["name"],
      sort_order = input["sort_order"],
      backend_protocol = input["backend_protocol"],
      frontend_host = input["frontend_host"],
      backend_host = input["backend_host"],
      balance_algorithm = input["balance_algorithm"],
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
          }))
        end
      end
    end

    if input["settings"] then
      params["settings"] = api_backend_settings_params(input["settings"])
    end
  end

  return params
end

return function(app)
  local function find_api_backend(self)
    self.api_backend = ApiBackend:find(self.params["id"])
    if not self.api_backend then
      return self:write({"Not Found", status = 404})
    end
  end

  app:match("/api-umbrella/v1/apis/:id(.:format)", respond_to({
    before = find_api_backend,
    GET = capture_errors_json(_M.show),
    POST = capture_errors_json(json_params(_M.update)),
    PUT = capture_errors_json(json_params(_M.update)),
    DELETE = capture_errors_json(_M.destroy),
  }))

  app:get("/api-umbrella/v1/apis(.:format)", capture_errors_json(_M.index))
  app:post("/api-umbrella/v1/apis(.:format)", capture_errors_json(json_params(_M.create)))
  app:match("/api-umbrella/v1/apis/:id/move_after(.:format)", respond_to({
    before = find_api_backend,
    PUT = capture_errors_json(json_params(_M.move_after)),
  }))
end
