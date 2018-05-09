local resty_random = require "resty.random"

local encode_base64 = ngx.encode_base64
local gsub = ngx.re.gsub
local random_bytes = resty_random.bytes

return function(length)
  local token = ""
  -- Loop until we've generated a valid token. The basic process:
  --
  -- 1. Generate secure random bytes.
  -- 2. Convert random bytes to base64.
  -- 3. Strip out special characters from base64 result, so we're left with
  --    just alphanumerics.
  --
  -- It should be extraordinarily rare that this needs to loop, but since we
  -- strip out some of the special characters from the resulting base64 string,
  -- this loops in case we strip more than expected.
  while string.len(token) < length do
    -- Attempt to generate cryptographically secure random bytes. We
    -- purposefully generate more bytes than we need, since we'll be stripping
    -- some of the base64 characters out.
    local num_bytes = length + 10
    local strong_random = random_bytes(num_bytes, true)
    if not strong_random then
      ngx.log(ngx.WARN, "Could not generate cryptographically secure random data. Falling back to non-secure random data.")
      strong_random = random_bytes(num_bytes, false)
    end

    -- Encode with base64.
    token = token .. encode_base64(strong_random)

    -- Strip +, /, and = out of the base64 result, since we just want a-z, A-Z,
    -- and 0-9 in our tokens.
    token = gsub(token, "[+/=]", "", "jo")

    -- Take just the number of characters requested.
    token = string.sub(token, 1, length)
  end

  return token
end
