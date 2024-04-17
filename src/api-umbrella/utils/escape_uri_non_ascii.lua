local escape_uri = ngx.escape_uri
local gsub = ngx.re.gsub

local function escape_match(match)
  return escape_uri(match[0])
end

return function(string)
  -- URL encode any non-ascii sequences found.
  --
  -- This is used in the logging so we send valid JSON to OpenSearch (JSON
  -- must be in UTF-8 and OpenSearch refuses to process any JSON containing
  -- non-UTF-8 characters). Ideally, we would probably want to only replace
  -- non-UTF-8 sequences with their URL encoded version, but this is the
  -- simpler, quicker approach.
  local result, _, gsub_err = gsub(string, "[^[:ascii:]]+", escape_match, "oj")
  if gsub_err then
    ngx.log(ngx.ERR, "regex error: ", gsub_err)
  end

  return result
end
