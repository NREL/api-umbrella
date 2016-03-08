-- List of headers where multiple headers are not allowed based on:
-- https://github.com/nodejs/node/blob/v5.4.1/lib/_http_incoming.js#L143-L160
local forbidden_multiple = {
  ["age"] = true,
  ["authorization"] = true,
  ["content-length"] = true,
  ["content-type"] = true,
  ["etag"] = true,
  ["expires"] = true,
  ["from"] = true,
  ["host"] = true,
  ["if-modified-since"] = true,
  ["if-unmodified-since"] = true,
  ["last-modified"] = true,
  ["location"] = true,
  ["max-forwards"] = true,
  ["proxy-authorization"] = true,
  ["referer"] = true,
  ["retry-after"] = true,
  ["server"] = true,
  ["user-agent"] = true,
}

-- Take a table of headers returned by ngx.req.get_headers or
-- ngx.resp.get_headers, and flatten nested arrays representing multiple values
-- of the same header into comma-separated strings (per RFC2616, Section 4.2).
-- For headers that don't support multiple values (defined above), we only take
-- the first value present.
return function(headers)
  for name, value in pairs(headers) do
    if type(value) == "table" then
      if forbidden_multiple[name] then
        headers[name] = value[1]
      else
        headers[name] = table.concat(value, ", ")
      end
    end
  end

  return headers
end
