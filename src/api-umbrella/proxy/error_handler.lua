local append_array = require "api-umbrella.utils.append_array"
local config = require "api-umbrella.proxy.models.file_config"
local deep_merge_overwrite_arrays = require "api-umbrella.utils.deep_merge_overwrite_arrays"
local http_headers = require "api-umbrella.utils.http_headers"
local httpsify_current_url = require "api-umbrella.utils.httpsify_current_url"
local is_hash = require "api-umbrella.utils.is_hash"
local lustache = require "lustache"
local mustache_unescape = require "api-umbrella.utils.mustache_unescape"
local path = require "pl.path"
local stringx = require "pl.stringx"
local tablex = require "pl.tablex"
local utils = require "api-umbrella.proxy.utils"
local xpcall_error_handler = require "api-umbrella.utils.xpcall_error_handler"

local deepcopy = tablex.deepcopy
local extension = path.extension
local keys = tablex.keys
local strip = stringx.strip

local supported_media_types = {
  {
    format = "json",
    media_type = "application",
    media_subtype = "json",
  },
  {
    format = "xml",
    media_type = "application",
    media_subtype = "xml",
  },
  {
    format = "xml",
    media_type = "text",
    media_subtype = "xml",
  },
  {
    format = "csv",
    media_type = "text",
    media_subtype = "csv",
  },
  {
    format = "html",
    media_type = "text",
    media_subtype = "html",
  },
}

local supported_formats = {}
for _, media in ipairs(supported_media_types) do
  if not supported_formats[media["format"]] then
    supported_formats[media["format"]] = media["media_type"] .. "/" .. media["media_subtype"]
  end
end

local function request_format()
  local request_path = ngx.ctx.uri_path
  if request_path then
    local format = extension(request_path)
    if format then
      format = string.sub(format, 2)
      if supported_formats[format] then
        return format, supported_formats[format]
      end
    end
  end

  local format_arg = ngx.var.arg_format
  if format_arg then
    if supported_formats[format_arg] then
      return format_arg, supported_formats[format_arg]
    end
  end

  local accept_header = ngx.var.http_accept
  if accept_header then
    local media = http_headers.preferred_accept(accept_header, supported_media_types)
    if media then
      return media["format"], media["media_type"] .. "/" .. media["media_subtype"]
    end
  end

  return "json", supported_formats["json"]
end

local function render_template(template, data, format, strip_whitespace)
  if not template or type(template) ~= "string" then
    ngx.log(ngx.ERR, "render_template passed invalid template (not a string)")
    return nil, "template error"
  end

  if not is_hash(data) then
    ngx.log(ngx.ERR, "render_template passed invalid data (not a table)")
    return nil, "template error"
  end

  -- Disable Mustache HTML escaping by default for non XML or HTML responses.
  if format ~= "xml" and format ~= "html" then
    template = mustache_unescape(template)
  end

  if strip_whitespace then
    -- Strip leading and trailing whitespace from template, since it's easy to
    -- introduce in multi-line templates and XML doesn't like if there's any
    -- leading space before the XML declaration.
    template = strip(template)
  end

  if format == "json" then
    for key, value in pairs(data) do
      data[key] = ndk.set_var.set_quote_json_str(value)
    end
  elseif format == "csv" then
    for key, value in pairs(data) do
      -- Quote the values for CSV output
      data[key] = '"' .. string.gsub(value, '"', '""') .. '"'
    end
  end

  local ok, output = xpcall(lustache.render, xpcall_error_handler, lustache, template, data)
  if ok then
    return output
  else
    ngx.log(ngx.ERR, "Mustache rendering error while rendering error template. Error: ", output, " Template: ", template)
    return nil, "template error"
  end
end

return function(denied_code, settings, extra_data)
  -- Store the gatekeeper rejection code for logging.
  ngx.ctx.gatekeeper_denied_code = denied_code

  -- Redirect "not_found" errors to HTTPS.
  --
  -- Since these errors aren't subject to an API Backend's HTTPS requirements
  -- (where we might return the "https_required" error), this helps ensure that
  -- requests to unknown location (neither API or website backend) are
  -- redirected to HTTPS like the rest of our non-API content. This ensures
  -- HTTPS redirects are in place for the root request on custom domains
  -- without a website or API at the root.
  if denied_code == "not_found" and config["router"]["redirect_not_found_to_https"] then
    if ngx.ctx.protocol ~= "https" then
      return ngx.redirect(httpsify_current_url(), ngx.HTTP_MOVED_PERMANENTLY)
    end
  end

  if denied_code == "redirect_https" then
    return ngx.redirect(httpsify_current_url(), ngx.HTTP_MOVED_PERMANENTLY)
  end

  if not settings then
    settings = config["default_api_backend_settings"]
  end

  -- Try to determine the format of the request (JSON, XML, etc), so we can
  -- attempt to match our response to the expected format.
  local format, content_type = request_format()

  -- Fetch "common" error data variables, for variables like "contact_url" that
  -- might be in use across all error messages.
  local common_data = deepcopy(settings["error_data"]["common"])
  if not is_hash(common_data) then
    -- Fallback to the built-in default data that isn't subject to any
    -- API-specific overrides (so it should always be a valid hash).
    common_data = deepcopy(config["default_api_backend_settings"]["error_data"]["common"])
  end

  -- Fetch the error data specific to this error message (over rate limit, key
  -- missing, etc).
  local error_data = deepcopy(settings["error_data"][denied_code])
  if not is_hash(error_data) then
    error_data = deepcopy(settings["error_data"]["internal_server_error"])
    if not is_hash(error_data) then
      -- Fallback to the built-in default data that isn't subject to any
      -- API-specific overrides (so it should always be a valid hash).
      error_data = deepcopy(config["default_api_backend_settings"]["error_data"]["internal_server_error"])
    end
  end

  -- Begin building the combined data available to the error template, starting
  -- with the base_url (based on the current URL being hit).
  local data = { base_url = utils.base_url() }

  -- Support legacy camel-case capitalization of variables. Moving forward,
  -- we're trying to clean things up and standardize on snake_case.
  data["baseUrl"] = data["base_url"]

  -- Later we need to loop through the data table roughly in order of
  -- insertion. Since tables have no order, keep track of things separately so
  -- we can loop through the logical groups in order.
  local data_ordered_keys = keys(data)

  -- Add the common data.
  deep_merge_overwrite_arrays(data, common_data)
  append_array(data_ordered_keys, keys(common_data))

  -- Support legacy camel-case capitalization of variables. Moving forward,
  -- we're trying to clean things up and standardize on snake_case.
  if not data["signupUrl"] then
    data["signupUrl"] = data["signup_url"]
    table.insert(data_ordered_keys, "signupUrl")
  end
  if not data["contactUrl"] then
    data["contactUrl"] = data["contact_url"]
    table.insert(data_ordered_keys, "contactUrl")
  end

  -- Add the error-specific data.
  deep_merge_overwrite_arrays(data, error_data)
  append_array(data_ordered_keys, keys(error_data))

  -- Add any extra data we might be passing internally.
  if extra_data then
    deep_merge_overwrite_arrays(data, extra_data)
    append_array(data_ordered_keys, keys(extra_data))
  end

  -- Loop through all the data variables we have, treating each variable as a
  -- potential template. This allows for variables to contain other variables.
  -- This allows for variables to contain others (like contact_url defaulting
  -- to "{{base_url}}/contact/"), as well as the error message variable to
  -- contain variables like "Contact us at {{contact_url}}".
  --
  -- We have to pay attention to the order with which we loop through things,
  -- because we have a bit of a circular issue with the example above of
  -- "message" containing "{{contact_url}}" and "contact_url" containing
  -- "{{base_url}}". We solve this by trying to loop through things in a
  -- logical order of how our variables typically build on each other (base_url
  -- first, followed by common_data, followed by the error_data). This isn't
  -- perfect, but saves us from multiple passes. But perhaps we should rethink
  -- this and disallow nested variables.
  for _, key in ipairs(data_ordered_keys) do
    if data[key] and type(data[key]) == "string" then
      data[key] = render_template(data[key], data)
    end
  end

  -- Determine the status code for the HTTP response.
  local status_code = data["status_code"] or 500

  -- Fetch the template for rendering the different formats of error messages
  -- (JSON, XML, etc).
  local template = settings["error_templates"][format]
  if not template or type(template) ~= "string" then
    -- Fallback to the built-in default template that isn't subject to any
    -- API-specific overrides (so it should always be a valid template).
    template = config["default_api_backend_settings"]["error_templates"][format]
  end

  -- Render the error message, substituting the variables.
  local output, template_err = render_template(template, data, format, true)

  -- Allow all errors to be loaded over CORS (in case any underlying APIs are
  -- expected to be accessed over CORS then we want to make sure errors are
  -- also allowed via CORS).
  ngx.header["Access-Control-Allow-Origin"] = "*"

  if not template_err then
    ngx.status = status_code
    ngx.header.content_type = content_type
    ngx.print(output)
    return ngx.exit(ngx.HTTP_OK)
  else
    ngx.status = 500
    ngx.header.content_type = "text/plain"
    ngx.print("Internal Server Error")
    return ngx.exit(ngx.HTTP_OK)
  end
end
