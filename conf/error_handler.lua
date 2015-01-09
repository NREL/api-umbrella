local lyaml = require "lyaml"
local cjson = require "cjson"
local lustache = require "lustache"
local moses = require "moses"
local inspect = require "inspect"
local utils = require "utils"
local path = require "pl.path"
local stringx = require "pl.stringx"
local log = ngx.log
local ERR = ngx.ERR

local supported_formats = {
  ["json"] = "application/json",
  ["xml"] = "application/xml",
  ["csv"] = "text/csv",
  ["html"] = "text/html",
}

local request_format = function()
  local request_path = ngx.var.uri
  if request_path then
    local format = path.extension(request_path)
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

  return "json"
end

local render_template = function(template, data, strip_whitespace)
  -- Disable Mustache HTML escaping by automatically turning all "{{var}}"
  -- references into unescaped "{{{var}}}" references. Since we're returning
  -- non-HTML errors, we don't want escaping. This lets us be a little lazy
  -- with our template definitions and not worry about mustache escape details
  -- there.
  local template = string.gsub(template, "{{([^{}]-)}}", "{{{%1}}}")

  if strip_whitespace then
    -- Strip leading and trailing whitespace from template, since it's easy to
    -- introduce in multi-line templates and XML doesn't like if there's any
    -- leading space before the XML declaration.
    template = stringx.strip(template)
  end

  return lustache:render(template, data)
end

return function(err)
  local settings = config["apiSettings"]

  local format = request_format()

  local data = moses.clone(settings["error_data"][err])
  if not data then
    data = moses.clone(settings["error_data"]["internal_server_error"])
  end

  data["message"] = render_template(data["message"], {
    ["baseUrl"] = utils.base_url(),
  })

  local status_code = data["status_code"]
  if not status_code then
    status_code = 500
  end

  local template = settings["error_templates"][format]
  local output = render_template(template, data, true)

  -- Allow all errors to be loaded over CORS (in case any underlying APIs are
  -- expected to be accessed over CORS then we want to make sure errors are
  -- also allowed via CORS).
  ngx.header["Access-Control-Allow-Origin"] = "*"

  ngx.status = status_code
  ngx.header.content_type = supported_formats[format]
  ngx.say(output)
  return ngx.exit(ngx.HTTP_OK)
end
