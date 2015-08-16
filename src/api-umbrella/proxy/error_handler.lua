local is_array = require "api-umbrella.utils.is_array"
local lustache = require "lustache"
local path = require "pl.path"
local plutils = require "pl.utils"
local stringx = require "pl.stringx"
local tablex = require "pl.tablex"
local utils = require "api-umbrella.proxy.utils"

local deep_merge_overwrite_arrays = utils.deep_merge_overwrite_arrays
local deepcopy = tablex.deepcopy
local extension = path.extension
local split = plutils.split
local strip = stringx.strip

local supported_formats = {
  ["json"] = "application/json",
  ["xml"] = "application/xml",
  ["csv"] = "text/csv",
  ["html"] = "text/html",
}

local supported_media_types = {}
for format, media_type in pairs(supported_formats) do
  local media_type_parts = split(media_type, "/", true)
  table.insert(supported_media_types, {
    format = format,
    media_type = media_type_parts[1],
    media_subtype = media_type_parts[2],
  })
end

local function request_format()
  local request_path = ngx.ctx.uri
  if request_path then
    local format = extension(request_path)
    if format then
      format = string.sub(format, 2)
      if supported_formats[format] then
        return format
      end
    end
  end

  local format_arg = ngx.var.arg_format
  if format_arg then
    if supported_formats[format_arg] then
      return format_arg
    end
  end

  -- TODO: Implement Accept header negotiation. Possibly modify something like:
  -- https://github.com/fghibellini/nginx-http-accept-lang/blob/master/lang.lua

  local accept_header = ngx.var.http_accept
  if accept_header then
    local format = utils.parse_accept(accept_header, supported_media_types)
    if format then
      return format
    end
  end

  return "json"
end

local function render_template(template, data, format, strip_whitespace)
  if not template or type(template) ~= "string" then
    ngx.log(ngx.ERR, "render_template passed invalid template (not a string)")
    return nil, "template error"
  end

  if not data or type(data) ~= "table" or is_array(data) then
    ngx.log(ngx.ERR, "render_template passed invalid data (not a table)")
    return nil, "template error"
  end

  -- Disable Mustache HTML escaping by automatically turning all "{{var}}"
  -- references into unescaped "{{{var}}}" references. Since we're returning
  -- non-HTML errors, we don't want escaping. This lets us be a little lazy
  -- with our template definitions and not worry about mustache escape details
  -- there.
  template = string.gsub(template, "{{([^{}]-)}}", "{{{%1}}}")

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
    -- TODO: Implement CSV escaping
  end

  local ok, output = pcall(lustache.render, lustache, template, data)
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

  if not settings then
    settings = config["apiSettings"]
  end

  local format = request_format()

  local data = deepcopy(settings["error_data"][denied_code])
  if not data or type(data) ~= "table" or is_array(data) then
    data = deepcopy(settings["error_data"]["internal_server_error"])
  end

  local message_data = deep_merge_overwrite_arrays({
    ["baseUrl"] = utils.base_url(),
  }, extra_data)
  data["message"] = render_template(data["message"], message_data)

  local status_code = data["status_code"]
  if not status_code then
    status_code = 500
  end

  local template = settings["error_templates"][format]
  local output, template_err = render_template(template, data, format, true)

  -- Allow all errors to be loaded over CORS (in case any underlying APIs are
  -- expected to be accessed over CORS then we want to make sure errors are
  -- also allowed via CORS).
  ngx.header["Access-Control-Allow-Origin"] = "*"

  if not template_err then
    ngx.status = status_code
    ngx.header.content_type = supported_formats[format]
    ngx.print(output)
    return ngx.exit(ngx.HTTP_OK)
  else
    ngx.status = 500
    ngx.header.content_type = "text/plain"
    ngx.print("Internal Server Error")
    return ngx.exit(ngx.HTTP_OK)
  end
end
