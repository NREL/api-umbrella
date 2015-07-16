-- Disable Mustache HTML escaping by automatically turning all "{{var}}"
-- references into unescaped "{{&var}}" references. Since we're returning
-- non-HTML errors, we don't want escaping. This lets us be a little lazy
-- with our template definitions and not worry about mustache escape details
-- there.
return function(template)
  return string.gsub(template, "{{([^#\\^/>{&!])", "{{&%1")
end
