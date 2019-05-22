-- Hash resty-session values using HMAC SHA-256.
--
-- resty-session defaults to HMAC SHA1 (since it's built in to OpenResty), but
-- we'll use sha256 in resty-session to better align with the rest of our
-- default hmac usage throughout our app.

local hmac = require "resty.nettle.hmac"

return function(secret_key, value)
  local hmac_sha256 = hmac.sha256.new(secret_key)
  hmac_sha256:update(value)
  return hmac_sha256:digest()
end
