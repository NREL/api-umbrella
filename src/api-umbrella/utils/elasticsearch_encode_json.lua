local cjson = require "cjson"
local iconv = require "iconv"

-- ElasticSearch requires all of the data sent to it be valid UTF-8. This
-- function encodes data into a JSON string, and then strips any non-UTF8
-- characters from the result.
--
-- When logging the requests to ElasticSearch, we actually make two passes at
-- special characters. First, we convert all the non-ASCII characters in the
-- URL into the URL-encoded values (see api-umbrella/proxy/log_utils and
-- escape_uri_non_ascii). All the other logged data (headers, etc) should
-- already be interpreted by nginx as utf-8. This is the second pass, and by
-- the time this method gets called, we shouldn't actually have any invalid
-- UTF-8 sequences in the data. However, this provides an extra sanity check to
-- ensure we don't unexpectedly have non-UTF8 data in other parts of our data
-- which would cause the logging to fail.
--
-- I'm not super fond of the double pass, since it seems a bit inefficient. I'd
-- like to get rid of the escape_uri_non_ascii business, but then it's hard to
-- log things in a consistent manner without stripping data, as this function
-- does. But defaulting to stripping data doesn't seem ideal either, since then
-- the logs aren't really accurate. So perhaps we'll revisit someday, but in
-- the meantime, this should ensure we don't accidentally send ElasticSearch
-- invalid data which will cause errors.
return function(data)
  local original_json = cjson.encode(data)

  local encoding_converter = iconv.new("utf-8//IGNORE", "utf-8")
  local json, err = encoding_converter:iconv(original_json)
  if err then
    ngx.log(ngx.ERR, "encoding error for elasticsearch data - non-utf8 chars have been stripped to continue")
  end

  return json
end
