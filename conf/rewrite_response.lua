local inspect = require "inspect"

local function set_default_headers(settings)
  if settings["_default_response_headers"] then
    local existing_headers = ngx.resp.get_headers()
    for _, header in ipairs(settings["_default_response_headers"]) do
      if not existing_headers[header["key"]] then
        ngx.header[header["key"]] = header["value"]
      end
    end
  end
end

local function set_override_headers(settings)
  if settings["_override_response_headers"] then
    for _, header in ipairs(settings["_override_response_headers"]) do
      ngx.header[header["key"]] = header["value"]
    end
  end
end

return function(settings)
  if settings then
    set_default_headers(settings)
    set_override_headers(settings)
  end
end
