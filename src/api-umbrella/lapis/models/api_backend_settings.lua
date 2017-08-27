local ApiBackendHttpHeader = require "api-umbrella.lapis.models.api_backend_http_header"
local cjson = require "cjson"
local is_empty = require("pl.types").is_empty
local model_ext = require "api-umbrella.utils.model_ext"
local split = require("ngx.re").split
local strip = require("pl.stringx").strip
local t = require("resty.gettext").gettext
local validation = require "resty.validation"

local json_null = cjson.null
local validate_field = model_ext.validate_field

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
  if headers then
    for index, header in ipairs(headers) do
      header["header_type"] = header_type
      header["sort_order"] = index
    end
  end
end

local ApiBackendSettings = model_ext.new_class("api_backend_settings", {
  relations = {
    { "http_headers", has_many = "ApiBackendHttpHeader", key = "api_backend_settings_id" },
  },

  default_response_headers_string = function(self)
    return http_headers_to_string(self, "response_default")
  end,

  error_data_yaml_strings = function(self)
    return ""
  end,

  headers_string = function(self)
    return http_headers_to_string(self, "request")
  end,

  override_response_headers_string = function(self)
    return http_headers_to_string(self, "response_override")
  end,

  as_json = function(self)
    local data = {
      id = self.id or json_null,
      allowed_ips = self.allowed_ips or json_null,
      allowed_referers = self.allowed_referers or json_null,
      anonymous_rate_limit_behavior = self.anonymous_rate_limit_behavior or json_null,
      api_key_verification_level = self.api_key_verification_level or json_null,
      api_key_verification_transition_start_at = self.api_key_verification_transition_start_at or json_null,
      append_query_string = self.append_query_string or json_null,
      authenticated_rate_limit_behavior = self.authenticated_rate_limit_behavior or json_null,
      default_response_headers = {},
      default_response_headers_string = self:default_response_headers_string() or json_null,
      disable_api_key = self.disable_api_key or json_null,
      error_data = self.error_data or json_null,
      error_data_yaml_strings = self:error_data_yaml_strings() or json_null,
      error_templates = self.error_templates or json_null,
      headers = {},
      headers_string = self:headers_string() or json_null,
      http_basic_auth = self.http_basic_auth or json_null,
      override_response_headers = {},
      override_response_headers_string = self:override_response_headers_string() or json_null,
      pass_api_key_header = self.pass_api_key_header or json_null,
      pass_api_key_query_param = self.pass_api_key_query_param or json_null,
      rate_limit_mode = self.rate_limit_mode or json_null,
      require_https = self.require_https or json_null,
      require_https_transition_start_at = self.require_https_transition_start_at or json_null,
      required_roles = self.required_roles or json_null,
      required_roles_override = self.required_roles_override or json_null,
    }

    local http_headers = self:get_http_headers()
    for _, http_header in ipairs(http_headers) do
      if http_header.header_type == "request" then
        table.insert(data["headers"], http_header:as_json())
      elseif http_header.header_type == "response_default" then
        table.insert(data["default_response_headers"], http_header:as_json())
      elseif http_header.header_type == "response_override" then
        table.insert(data["override_response_headers"], http_header:as_json())
      end
    end
    setmetatable(data["default_response_headers"], cjson.empty_array_mt)
    setmetatable(data["headers"], cjson.empty_array_mt)
    setmetatable(data["override_response_headers"], cjson.empty_array_mt)

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
}, {
  before_validate = function(_, values)
    if values["default_response_headers_string"] then
      values["default_response_headers"] = string_to_http_headers(values["default_response_headers_string"])
    end
    if values["default_response_headers"] then
      add_http_headers_metadata(values["default_response_headers"], "response_default")
    end

    if values["headers_string"] then
      values["headers"] = string_to_http_headers(values["headers_string"])
    end
    if values["headers"] then
      add_http_headers_metadata(values["headers"], "request")
    end

    if values["override_response_headers_string"] then
      values["override_response_headers"] = string_to_http_headers(values["override_response_headers_string"])
    end
    if values["override_response_headers"] then
      add_http_headers_metadata(values["override_response_headers"], "response_override")
    end
  end,

  validate = function(_, data)
    local errors = {}
    validate_field(errors, data, "require_https", validation.optional:regex("^(required_return_error|transition_return_error|optional)$", "jo"), t("is not included in the list"))
    validate_field(errors, data, "api_key_verification_level", validation.optional:regex("^(none|transition_email|required_email)$", "jo"), t("is not included in the list"))
    validate_field(errors, data, "rate_limit_mode", validation.optional:regex("^(unlimited|custom)$", "jo"), t("is not included in the list"))
    validate_field(errors, data, "anonymous_rate_limit_behavior", validation.optional:regex("^(ip_fallback|ip_only)$", "jo"), t("is not included in the list"))
    validate_field(errors, data, "authenticated_rate_limit_behavior", validation.optional:regex("^(all|api_key_only)$", "jo"), t("is not included in the list"))
    return errors
  end,

  after_save = function(self, values)
    model_ext.has_many_save(self, values, "default_response_headers")
    model_ext.has_many_save(self, values, "headers")
    model_ext.has_many_save(self, values, "override_response_headers")
  end
})

return ApiBackendSettings
