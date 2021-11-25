-- Allow stripping specific cookies before caching so responses with cookies
-- can still be cached if the cookies are irrelevant.
--
-- Note: Due to Traffic Server's Lua cookie setting making it difficult to
-- deal with setting multiple cookies (it only accepts a single string), we
-- will only strip cookies if all of the cookies can be stripped and
-- therefore the response can be cached. If only some of the cookies can be
-- stripped, we will leave all the cookies as-is.
--
-- Once Traffic Server 9.1 is released, it should have a better way to fetch
-- these multiple headers (via ts.server_response.header_table), so we can
-- improve this once that is released.

local rex = require "rex_pcre2"

local rex_gmatch = rex.gmatch
local rex_new = rex.new

-- Regex for attempting to extract all of the cookie names from the single
-- comma-delimited string.
local cookie_name_regex = rex_new([[(?:^|,)([^ =]+)=]])
cookie_name_regex:jit_compile()

local strip_response_cookies_regex
function __init__(argtb)
  if #argtb < 1 then
    ts.error(argtb[0] .. " strip_response_cookies regex file parameter required")
    return -1
  end

  -- Passing the regex as an argument can fail when spaces or quotes are
  -- involved in the regex, so instead, we'll read the regex in from a template
  -- file.
  local regex_filename = argtb[1]
  local file, file_err = io.open(regex_filename, "rb")
  if file_err then
    ts.error("Error opening strip_response_cookies regex file: " .. file_err)
    return -1
  end

  local regex_string = file:read("*all")

  strip_response_cookies_regex = rex_new(regex_string, "i")
  strip_response_cookies_regex:jit_compile()
end

function do_global_read_response()
  -- Fetch all the cookies being set on the response.
  local set_cookie = ts.server_response.header["Set-Cookie"]
  if set_cookie then
    local strip_all_cookies = false

    -- Traffic Server's Lua API returns multiple cookes as comma-delimited
    -- values. However, this becomes tricky to parse, since "Set-Cookie"
    -- headers can contain commas themselves. So we'll do our best to try and
    -- parse this by looking for a cookie name either at the beginning of the
    -- string, or immediately following a comma (but this shouldn't match
    -- commas present in "Expires" arguments).
    for cookie_name in rex_gmatch(set_cookie, cookie_name_regex) do
      if strip_response_cookies_regex:find(cookie_name) then
        strip_all_cookies = true
      else
        strip_all_cookies = false
        break
      end
    end

    -- Due to the limitations in setting multiple headers, we will only reset
    -- all the cookies if all of the headers were eligible for stripping.
    if strip_all_cookies then
      ts.server_response.header["Set-Cookie"] = nil
    end
  end
end
