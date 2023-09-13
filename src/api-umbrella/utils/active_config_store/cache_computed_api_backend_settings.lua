local append_array = require "api-umbrella.utils.append_array"
local deep_defaults = require "api-umbrella.utils.deep_defaults"
local deep_merge_overwrite_arrays = require "api-umbrella.utils.deep_merge_overwrite_arrays"
local escape_regex = require "api-umbrella.utils.escape_regex"
local is_empty = require "api-umbrella.utils.is_empty"
local is_hash = require "api-umbrella.utils.is_hash"
local iso8601_ms_to_timestamp = require("api-umbrella.utils.time").iso8601_ms_to_timestamp
local string_template = require "api-umbrella.utils.string_template"
local strip = require("pl.stringx").strip
local tablex = require "pl.tablex"
local unique = require("pl.seq").unique

local decode_args = ngx.decode_args
local deepcopy = tablex.deepcopy
local encode_base64 = ngx.encode_base64
local re_gsub = ngx.re.gsub
local re_sub = ngx.re.sub
local table_keys = tablex.keys

local function cache_error_data(config, settings)
  if not settings["error_data"] then return end

  -- Start with the base error_data (rather than the merged error_data from
  -- settings), since we want to be more cautious about how this specific error
  -- handling data gets merged to make sure the merged data is of the
  -- appropriate type, etc (so we don't generate unexpected errors when
  -- returning our error messages).
  local error_data = deepcopy(config["default_api_backend_settings"]["error_data"])

  -- Merge the "common" values first.
  if settings["error_data"] and is_hash(settings["error_data"]["common"]) then
    deep_merge_overwrite_arrays(error_data["common"], settings["error_data"]["common"])
  end

  -- Merge the error-specific data.
  for error_type, data in pairs(error_data) do
    if error_type ~= "common" then
      -- Use the "common" values as defaults.
      deep_defaults(data, error_data["common"])

      -- Merge the setting-specific overrides on top.
      if settings["error_data"] and is_hash(settings["error_data"][error_type]) then
        deep_merge_overwrite_arrays(data, settings["error_data"][error_type])
      end

      -- Support legacy camel-case capitalization of variables. Moving
      -- forward, we're trying to clean things up and standardize on
      -- snake_case.
      if not data["baseUrl"] and data["base_url"] then
        data["baseUrl"] = data["base_url"]
      end
      if not data["signupUrl"] and data["signup_url"] then
        data["signupUrl"] = data["signup_url"]
      end
      if not data["contactUrl"] and data["contact_url"] then
        data["contactUrl"] = data["contact_url"]
      end
    end

    -- Parse the error data for variables. We may not be able to substitute
    -- all of them, but this at least takes care of nested variables with a
    -- first pass. Any unknown variables will remain as-is.
    for key, value in pairs(data) do
      if type(value) == "string" then
        data[key] = string_template(value, data)
      end
    end
  end

  settings["_error_data"] = error_data
  settings["error_data"] = nil
end

local function cache_error_templates(config, settings)
  if not settings["error_templates"] then return end

  -- Start with the base error_data (rather than the merged error_data from
  -- settings), since we want to be more cautious about how this specific error
  -- handling data gets merged to make sure the merged data is of the
  -- appropriate type, etc (so we don't generate unexpected errors when
  -- returning our error messages).
  local error_templates = deepcopy(config["default_api_backend_settings"]["error_templates"])

  if is_hash(settings["error_templates"]) then
    for format, _ in pairs(error_templates) do
      -- Merge the setting-specific overrides on top.
      local settings_template = settings["error_templates"][format]
      if type(settings_template) == "string" then
        error_templates[format] = settings_template
      end

      -- Strip leading and trailing whitespace from template, since it's easy to
      -- introduce in multi-line templates and XML doesn't like if there's any
      -- leading space before the XML declaration.
      error_templates[format] = strip(error_templates[format])
    end
  end

  settings["_error_templates"] = error_templates
  settings["error_templates"] = nil
end

return function(config, settings, parent_settings)
  if not settings then return end

  if parent_settings then
    -- If we're merging `required_roles` from parent and child settings, we
    -- want to handle that differently, since we want them to default to be
    -- additive, and only override in the child if specified. So first, grab a
    -- copy of the parent and child required roles.
    local parent_required_roles
    if parent_settings and parent_settings["required_roles"] then
      parent_required_roles = deepcopy(parent_settings["required_roles"])
    end
    local orig_required_roles = deepcopy(settings["required_roles"] or {})

    -- Perform the merging so any missing settings default to the parent
    -- values.
    deep_defaults(settings, parent_settings)

    -- Handle the special case of merging `required_roles` based on whether or
    -- not the child should override or append.
    settings["_required_roles"] = orig_required_roles
    if not settings["required_roles_override"] and parent_required_roles then
      append_array(settings["_required_roles"], parent_required_roles)
      settings["_required_roles"] = unique(settings["_required_roles"], true)
    end
  else
    settings["_required_roles"] = settings["required_roles"]
  end
  settings["required_roles"] = nil

  -- Parse and cache the allowed IPs as CIDR ranges.
  if not is_empty(settings["allowed_ips"]) then
    settings["_allowed_ips"] = settings["allowed_ips"]
  end
  settings["allowed_ips"] = nil

  -- Parse and cache the allowed referers as matchers
  if not is_empty(settings["allowed_referers"]) then
    settings["_allowed_referer_regexes"] = {}
    settings["_allowed_referer_origin_regexes"] = {}
    local gsub_err
    for _, referer in ipairs(settings["allowed_referers"]) do
      local regex = escape_regex(referer)
      regex, _, gsub_err = re_gsub(regex, [[\\\*]], ".*", "jo")
      if gsub_err then
        ngx.log(ngx.ERR, "regex error: ", gsub_err)
      end
      regex = "^" .. regex .. "$"
      table.insert(settings["_allowed_referer_regexes"], regex)

      -- If the Referer header isn't present, but Origin is, then use slightly
      -- different behavior to match against the Origin header, which doesn't
      -- include any part of the URL path. So take the referer regex and remove
      -- any path portion of the matcher (the last "/" following something that
      -- looks like a domain or IP).
      local origin_regex, _, origin_sub_err = re_sub(regex, "(.*[A-Za-z0-9])/.*$", "$1$$", "jo")
      if origin_sub_err then
        ngx.log(ngx.ERR, "regex error: ", origin_sub_err)
      end
      table.insert(settings["_allowed_referer_origin_regexes"], origin_regex)
    end
  end
  settings["allowed_referers"] = nil

  if not is_empty(settings["headers"]) then
    settings["_headers"] = {}
    for _, header in ipairs(settings["headers"]) do
      if header["value"] and string.find(header["value"], "{{") then
        header["_process_as_template"] = true
      end

      table.insert(settings["_headers"], header)
    end
  end
  settings["headers"] = nil

  if not is_empty(settings["default_response_headers"]) then
    settings["_default_response_headers"] = settings["default_response_headers"]
  end
  settings["default_response_headers"] = nil

  if not is_empty(settings["override_response_headers"]) then
    settings["_override_response_headers"] = settings["override_response_headers"]
  end
  settings["override_response_headers"] = nil

  if not is_empty(settings["append_query_string"]) then
    settings["_append_query_arg_names"] = table_keys(decode_args(settings["append_query_string"]))
  elseif settings["append_query_string"] then
    settings["append_query_string"] = nil
  end

  if not is_empty(settings["http_basic_auth"]) then
    settings["_http_basic_auth_header"] = "Basic " .. encode_base64(settings["http_basic_auth"])
  end
  settings["http_basic_auth"] = nil

  if settings["api_key_verification_transition_start_at"] then
    settings["_api_key_verification_transition_start_at"] = iso8601_ms_to_timestamp(settings["api_key_verification_transition_start_at"])
  end
  settings["api_key_verification_transition_start_at"] = nil

  if settings["require_https_transition_start_at"] then
    settings["_require_https_transition_start_at"] = iso8601_ms_to_timestamp(settings["require_https_transition_start_at"])
  end
  settings["require_https_transition_start_at"] = nil

  if settings["rate_limits"] then
    for _, limit in ipairs(settings["rate_limits"]) do
      -- Backwards compatibility for with the old "limit" field
      -- (instead of the renamed "limit_to" we now use for easier SQL
      -- compatibility). The published config contains "limit" for API
      -- compatibility purposes, but the API users data use "limit_to" since we
      -- pull that directly from the database.
      if not limit["limit_to"] and limit["limit"] then
        limit["limit_to"] = limit["limit"]
        limit["limit"] = nil
      end

      -- Backwards compatibility camel-case capitalization for "limit_by". The
      -- published config uses "apiKey" while users from the database use the
      -- raw "api_key" value
      if limit["limit_by"] == "apiKey" then
        limit["limit_by"] = "api_key"
      end

      limit["_duration_sec"] = limit["duration"] / 1000

      if limit["response_headers"] then
        settings["_rate_limits_response_header_limit"] = limit["limit_to"]
      end
    end
  end

  -- Pre-cache the error data and templates accounting for merging in defaults.
  --
  -- Note that this may result in lot of large duplicate error data end error
  -- template strings even for backends that don't have customizations. But
  -- this optimizes fetching the data when rendering templates. And since we
  -- compress the serialized api backend config in the shared dict storage,
  -- this actually won't balloon memory too much. And since duplicate strings
  -- are only allocated once in Lua, it also shouldn't increase the runtime
  -- memory.
  cache_error_data(config, settings)
  cache_error_templates(config, settings)
end
