local is_empty = require "api-umbrella.utils.is_empty"

-- This allows us to support IE8-9 and their shimmed pseudo-CORS support. This
-- parses the post body as form data, even if the content-type is text/plain or
-- unknown.
--
-- The issue is that IE8-9 will send POST data with an empty Content-Type (see:
-- http://goo.gl/oumNaF). To handle this, we force parsing of our post body as
-- form data so IE's form data is present on the normal "params" object. Also
-- note that apparently historically IE8-9 would actually send the data as
-- "text/plain" rather than an empty content-type, so we handle any content
-- type.
return function(fn)
  return function(self, ...)
    if ngx.req.get_method() == "POST" and is_empty(self.POST) then
      ngx.req.read_body()
      local args = ngx.req.get_post_args()
      local support = self.__class.support
      support.add_params(self, args, "POST")
    end

    return fn(self, ...)
  end
end
