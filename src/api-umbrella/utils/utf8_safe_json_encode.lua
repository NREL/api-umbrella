local json_encode = require "api-umbrella.utils.json_encode"
local utf8_clean = require("lua-utf8").clean

-- A JSON encoding method that ensures valid UTF-8 output. Technically JSON
-- must conform to UTF-8, but the normal `cjson` library does not enforce this.
-- There is extra overhead in this processing, so we will only use this in
-- cases where we have untrusted input and is necessary (for example, logging
-- to OpenSearch, since otherwise OpenSearch also doesn't perform any
-- validations, so we can end up with unparseable data if we send OpenSearch
-- invalid UTF-8 data).
--
-- Note that this takes the approach of encoding to a single JSON string first,
-- and then sanitizing that after the fact. In benchmarks, this appears
-- normally faster than trying to sanitize all of the inputs first (eg, on a
-- nested table). I believe this approach is still safe and should always
-- produce valid JSON output, but I'm not 100% sure that some edge-case doesn't
-- exist that might lead to invalid JSON (eg, if somehow the utf-cleaning
-- process messes with the quotes inside the JSON). So we could revisit this
-- approach if we discover edge cases, but in the meantime, we'll go with this
-- (the main risk would be invalid utf-8 input could lead to invalid JSON
-- output, in which case we might miss logging those entries).
return function(data)
  local original_json = json_encode(data)
  local clean_json, was_valid_utf8 = utf8_clean(original_json)
  if not was_valid_utf8 then
    ngx.log(ngx.WARN, "json contained invalid utf-8, original: ", original_json)
    ngx.log(ngx.WARN, "json contained invalid utf-8, cleaned: ", clean_json)
  elseif not clean_json then
    ngx.log(ngx.ERR, "failed to perform utf-8 cleaning for json: ", original_json)
  end

  return clean_json
end
