local ApiBackendHttpHeader = require "api-umbrella.web-app.models.api_backend_http_header"
local ApiRole = require "api-umbrella.web-app.models.api_role"
local RateLimit = require "api-umbrella.web-app.models.rate_limit"
local db = require "lapis.db"
local is_array = require "api-umbrella.utils.is_array"
local is_empty = require "api-umbrella.utils.is_empty"
local is_hash = require "api-umbrella.utils.is_hash"
local json_array_fields = require "api-umbrella.web-app.utils.json_array_fields"
local json_null_default = require "api-umbrella.web-app.utils.json_null_default"
local lyaml = require "lyaml"
local model_ext = require "api-umbrella.web-app.utils.model_ext"
local nillify_yaml_nulls = require "api-umbrella.utils.nillify_yaml_nulls"
local pg_encode_array = require "api-umbrella.utils.pg_encode_array"
local pg_encode_json = require("pgmoon.json").encode_json
local pretty_yaml_dump = require "api-umbrella.web-app.utils.pretty_yaml_dump"
local split = require("ngx.re").split
local strip = require("pl.stringx").strip
local t = require("api-umbrella.web-app.utils.gettext").gettext
local time = require "api-umbrella.utils.time"
local validation_ext = require "api-umbrella.web-app.utils.validation_ext"

local db_null = db.NULL
local db_raw = db.raw
local validate_field = model_ext.validate_field
local validate_relation_uniqueness = model_ext.validate_relation_uniqueness

local function http_headers_to_string(self, header_type)
  if not self._http_header_strings then
    local strings = {}
    local http_headers = self:get_http_headers()
    if http_headers then
      for _, http_header in ipairs(http_headers) do
        if not strings[http_header.header_type] then
          strings[http_header.header_type] = {}
        end

        table.insert(strings[http_header.header_type], http_header:string_value())
      end
    end

    self._http_header_strings = {}
    for strings_header_type, strings_values in pairs(strings) do
      self._http_header_strings[strings_header_type] = table.concat(strings_values, "\n")
    end
  end

  return self._http_header_strings[header_type] or ""
end

local function string_to_http_headers(value)
  local headers = {}
  if value and type(value) == "string" then
    local lines = split(value, "[\r\n]+")
    for _, line in ipairs(lines) do
      if not is_empty(strip(line)) then
        local parts = split(line, ":", nil, nil, 2)
        table.insert(headers, {
          key = strip(parts[1] or ""),
          value = strip(parts[2] or ""),
        })
      end
    end
  end

  return headers
end

local function add_http_headers_metadata(headers, header_type)
  if is_array(headers) and headers ~= db_null then
    for index, header in ipairs(headers) do
      header["header_type"] = header_type
      header["sort_order"] = index
    end
  end
end

local ApiBackendSettings = model_ext.new_class("api_backend_settings", {
  relations = {
    {
      "http_headers",
      has_many = "ApiBackendHttpHeader",
      key = "api_backend_settings_id",
      order = "sort_order",
    },
    {
      "rate_limits",
      has_many = "RateLimit",
      key = "api_backend_settings_id",
      order = "duration, limit_by",
    },
    model_ext.has_and_belongs_to_many("required_roles", "ApiRole", {
      join_table = "api_backend_settings_required_roles",
      foreign_key = "api_backend_settings_id",
      association_foreign_key = "api_role_id",
      order = "id",
    }),
  },

  default_response_headers_string = function(self)
    return http_headers_to_string(self, "response_default")
  end,

  error_data_yaml_strings = function(self)
    if not self._error_data_yaml_strings then
      self._error_data_yaml_strings = {}
      if self.error_data then
        for key, value in pairs(self.error_data) do
          self._error_data_yaml_strings[key] = pretty_yaml_dump(value)
        end
      end
    end

    return self._error_data_yaml_strings
  end,

  headers_string = function(self)
    return http_headers_to_string(self, "request")
  end,

  override_response_headers_string = function(self)
    return http_headers_to_string(self, "response_override")
  end,

  required_role_ids = function(self)
    local required_role_ids = {}
    for _, role in ipairs(self:get_required_roles()) do
      table.insert(required_role_ids, role.id)
    end

    return required_role_ids
  end,

  as_json = function(self, options)
    local data = {
      id = json_null_default(self.id),
      allowed_ips = json_null_default(self.allowed_ips),
      allowed_referers = json_null_default(self.allowed_referers),
      anonymous_rate_limit_behavior = json_null_default(self.anonymous_rate_limit_behavior),
      api_key_verification_level = json_null_default(self.api_key_verification_level),
      api_key_verification_transition_start_at = json_null_default(time.postgres_to_iso8601(self.api_key_verification_transition_start_at)),
      append_query_string = json_null_default(self.append_query_string),
      authenticated_rate_limit_behavior = json_null_default(self.authenticated_rate_limit_behavior),
      default_response_headers = {},
      default_response_headers_string = json_null_default(self:default_response_headers_string()),
      disable_api_key = json_null_default(self.disable_api_key),
      error_data = json_null_default(self.error_data),
      error_data_yaml_strings = json_null_default(self:error_data_yaml_strings()),
      error_templates = json_null_default(self.error_templates),
      headers = {},
      headers_string = json_null_default(self:headers_string()),
      http_basic_auth = json_null_default(self.http_basic_auth),
      override_response_headers = {},
      override_response_headers_string = json_null_default(self:override_response_headers_string()),
      pass_api_key_header = json_null_default(self.pass_api_key_header),
      pass_api_key_query_param = json_null_default(self.pass_api_key_query_param),
      rate_limit_bucket_name = json_null_default(self.rate_limit_bucket_name),
      rate_limit_mode = json_null_default(self.rate_limit_mode),
      rate_limits = {},
      redirect_https = json_null_default(self.redirect_https),
      require_https = json_null_default(self.require_https),
      require_https_transition_start_at = json_null_default(time.postgres_to_iso8601(self.require_https_transition_start_at)),
      required_roles = json_null_default(self:required_role_ids()),
      required_roles_override = json_null_default(self.required_roles_override),
    }

    local http_headers = self:get_http_headers()
    for _, http_header in ipairs(http_headers) do
      if http_header.header_type == "request" then
        table.insert(data["headers"], http_header:as_json(options))
      elseif http_header.header_type == "response_default" then
        table.insert(data["default_response_headers"], http_header:as_json(options))
      elseif http_header.header_type == "response_override" then
        table.insert(data["override_response_headers"], http_header:as_json(options))
      end
    end

    local rate_limits = self:get_rate_limits()
    for _, rate_limit in ipairs(rate_limits) do
      table.insert(data["rate_limits"], rate_limit:as_json(options))
    end

    json_array_fields(data, {
      "default_response_headers",
      "headers",
      "override_response_headers",
      "rate_limits",
      "required_roles",
    }, options)

    if options and options["for_publishing"] then
      data["require_https_transition_start_at"] = json_null_default(time.postgres_to_iso8601_ms(self.require_https_transition_start_at))
      data["api_key_verification_transition_start_at"] = json_null_default(time.postgres_to_iso8601_ms(self.api_key_verification_transition_start_at))
      data["default_response_headers_string"] = nil
      data["error_data_yaml_strings"] = nil
      data["headers_string"] = nil
      data["override_response_headers_string"] = nil
    end

    return data
  end,

  default_response_headers_update_or_create = function(self, header_values)
    return model_ext.has_many_update_or_create(self, ApiBackendHttpHeader, "api_backend_settings_id", header_values)
  end,

  default_response_headers_delete_except = function(self, keep_header_ids)
    return model_ext.has_many_delete_except(self, ApiBackendHttpHeader, "api_backend_settings_id", keep_header_ids, "header_type = 'response_default'")
  end,

  headers_update_or_create = function(self, header_values)
    return model_ext.has_many_update_or_create(self, ApiBackendHttpHeader, "api_backend_settings_id", header_values)
  end,

  headers_delete_except = function(self, keep_header_ids)
    return model_ext.has_many_delete_except(self, ApiBackendHttpHeader, "api_backend_settings_id", keep_header_ids, "header_type = 'request'")
  end,

  override_response_headers_update_or_create = function(self, header_values)
    return model_ext.has_many_update_or_create(self, ApiBackendHttpHeader, "api_backend_settings_id", header_values)
  end,

  override_response_headers_delete_except = function(self, keep_header_ids)
    return model_ext.has_many_delete_except(self, ApiBackendHttpHeader, "api_backend_settings_id", keep_header_ids, "header_type = 'response_override'")
  end,

  rate_limits_update_or_create = function(self, rate_limit_values)
    return model_ext.has_many_update_or_create(self, RateLimit, "api_backend_settings_id", rate_limit_values)
  end,

  rate_limits_delete_except = function(self, keep_rate_limit_ids)
    return model_ext.has_many_delete_except(self, RateLimit, "api_backend_settings_id", keep_rate_limit_ids)
  end,
}, {
  authorize = function()
    return true
  end,

  before_validate = function(_, values)
    if values["error_data_yaml_strings"] then
      values["error_data"] = {}
      if is_hash(values["error_data_yaml_strings"]) then
        for key, value in pairs(values["error_data_yaml_strings"]) do
          local ok, field_data = pcall(lyaml.load, value)
          if ok then
            if is_hash(field_data) then
              nillify_yaml_nulls(field_data)
            end
            values["error_data"][key] = field_data
          else
            if not values["_error_data_yaml_strings_parse_errors"] then
              values["_error_data_yaml_strings_parse_errors"] = {}
            end

            values["_error_data_yaml_strings_parse_errors"][key] = string.format(t("YAML parsing error: %s"), (field_data or ""))
          end
        end
      end
    end

    if values["default_response_headers_string"] then
      values["default_response_headers"] = string_to_http_headers(values["default_response_headers_string"])
    end
    add_http_headers_metadata(values["default_response_headers"], "response_default")

    if values["headers_string"] then
      values["headers"] = string_to_http_headers(values["headers_string"])
    end
    add_http_headers_metadata(values["headers"], "request")

    if values["override_response_headers_string"] then
      values["override_response_headers"] = string_to_http_headers(values["override_response_headers_string"])
    end
    add_http_headers_metadata(values["override_response_headers"], "response_override")
  end,

  validate = function(_, data)
    local errors = {}
    validate_field(errors, data, "append_query_string", t("Append Query String Parameters"), {
      { validation_ext.db_null_optional.string:maxlen(255), string.format(t("is too long (maximum is %d characters)"), 255) },
    })
    validate_field(errors, data, "http_basic_auth", t("HTTP Basic Authentication"), {
      { validation_ext.db_null_optional.string:maxlen(255), string.format(t("is too long (maximum is %d characters)"), 255) },
    })
    validate_field(errors, data, "require_https", t("Require HTTPS"), {
      { validation_ext.db_null_optional:regex("^(required_return_error|transition_return_error|optional)$", "jo"), t("is not included in the list") },
    })
    validate_field(errors, data, "redirect_https", t("Redirect HTTPS"), {
      { validation_ext.db_null_optional.boolean, t("can't be blank") },
    })
    validate_field(errors, data, "disable_api_key", t("API Key Checks"), {
      { validation_ext.db_null_optional.boolean, t("can't be blank") },
    })
    validate_field(errors, data, "api_key_verification_level", t("API key verification level"), {
      { validation_ext.db_null_optional:regex("^(none|transition_email|required_email)$", "jo"), t("is not included in the list") },
    })
    validate_field(errors, data, "required_role_ids", t("Required Roles"), {
      { validation_ext.db_null_optional.array_table, t("is not an array") },
      { validation_ext.db_null_optional.array_strings, t("must be an array of strings") },
      { validation_ext.db_null_optional:array_strings_maxlen(255), string.format(t("is too long (maximum is %d characters)"), 255) },
    }, { error_field = "roles" })
    validate_field(errors, data, "required_roles_override", t("Override required roles from \"Global Request Settings\""), {
      { validation_ext.db_null_optional.boolean, t("can't be blank") },
    })
    validate_field(errors, data, "pass_api_key_header", t("Via HTTP header"), {
      { validation_ext.db_null_optional.boolean, t("can't be blank") },
    })
    validate_field(errors, data, "pass_api_key_query_param", t("Via GET query parameter"), {
      { validation_ext.db_null_optional.boolean, t("can't be blank") },
    })
    validate_field(errors, data, "rate_limit_bucket_name", t("Rate limit bucket"), {
      { validation_ext.db_null_optional.string:maxlen(255), string.format(t("is too long (maximum is %d characters)"), 255) },
    })
    validate_field(errors, data, "rate_limit_mode", t("Rate limit mode"), {
      { validation_ext.db_null_optional:regex("^(unlimited|custom)$", "jo"), t("is not included in the list") },
    })
    validate_field(errors, data, "anonymous_rate_limit_behavior", t("Anonymous rate limit behavior"), {
      { validation_ext.db_null_optional:regex("^(ip_fallback|ip_only)$", "jo"), t("is not included in the list") },
    })
    validate_field(errors, data, "authenticated_rate_limit_behavior", t("Authenticated rate limit behavior"), {
      { validation_ext.db_null_optional:regex("^(all|api_key_only)$", "jo"), t("is not included in the list") },
    })
    validate_field(errors, data, "allowed_ips", t("Restrict Access to IPs"), {
      { validation_ext.db_null_optional.array_table, t("is not an array") },
      { validation_ext.db_null_optional.array_strings, t("must be an array of strings") },
      { validation_ext.db_null_optional.array_strings_ips, t("invalid IP") },
    })
    validate_field(errors, data, "allowed_referers", t("Restrict Access to HTTP Referers"), {
      { validation_ext.db_null_optional.array_table, t("is not an array") },
      { validation_ext.db_null_optional.array_strings, t("must be an array of strings") },
      { validation_ext.db_null_optional:array_strings_maxlen(500), string.format(t("is too long (maximum is %d characters)"), 500) },
    })
    validate_relation_uniqueness(errors, data, "rate_limits", "duration", t("Duration"), {
      "api_backend_settings_id",
      "limit_by",
      "duration",
    })

    if data["error_data"] then
      if not is_hash(data["error_data"]) then
        model_ext.add_error(errors, "settings.error_data", t("Settings error data"), t("unexpected type (must be a hash)"))
      else
        for key, value in pairs(data["error_data"]) do
          if not is_hash(value) then
            model_ext.add_error(errors, "settings.error_data." .. key, string.format(t("Settings error data %s"), key), t("unexpected type (must be a hash)"))
          end
        end
      end
    end

    if data["_error_data_yaml_strings_parse_errors"] then
      for key, value in pairs(data["_error_data_yaml_strings_parse_errors"]) do
        model_ext.add_error(errors, "settings.error_data_yaml_strings." .. key, string.format(t("Settings error data YAML strings %s"), key), value)
      end
    end

    if data["error_templates"] then
      if not is_hash(data["error_templates"]) then
        model_ext.add_error(errors, "settings.error_templates", t("Settings error templates"), t("unexpected type (must be a hash)"))
      else
        for key, value in pairs(data["error_templates"]) do
          if type(value) ~= "string" then
            model_ext.add_error(errors, "settings.error_templates." .. key, string.format(t("Settings error templates %s"), key), t("unexpected type (must be a string)"))
          end
        end
      end
    end

    return errors
  end,

  before_save = function(_, values)
    if is_array(values["allowed_ips"]) and values["allowed_ips"] ~= db_null then
      values["allowed_ips"] = db_raw(pg_encode_array(values["allowed_ips"]) .. "::inet[]")
    end

    if is_array(values["allowed_referers"]) and values["allowed_referers"] ~= db_null then
      values["allowed_referers"] = db_raw(pg_encode_array(values["allowed_referers"]))
    end

    if is_hash(values["error_data"]) and values["error_data"] ~= db_null then
      values["error_data"] = db_raw(pg_encode_json(values["error_data"]))
    end

    if is_hash(values["error_templates"]) and values["error_templates"] ~= db_null then
      values["error_templates"] = db_raw(pg_encode_json(values["error_templates"]))
    end
  end,

  after_save = function(self, values)
    model_ext.has_many_save(self, values, "default_response_headers")
    model_ext.has_many_save(self, values, "headers")
    model_ext.has_many_save(self, values, "override_response_headers")
    model_ext.has_many_save(self, values, "rate_limits")
    ApiRole.insert_missing(values["required_role_ids"])
    model_ext.save_has_and_belongs_to_many(self, values["required_role_ids"], {
      join_table = "api_backend_settings_required_roles",
      foreign_key = "api_backend_settings_id",
      association_foreign_key = "api_role_id",
    })
  end
})

return ApiBackendSettings
