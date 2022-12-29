-- Hash values using HMAC SHA-256
--
-- The "secret_key" config value defined in api-umbrella.yml is used as the
-- hash key. When this key changes, previously hashed data will need to be
-- re-hashed.

local config = require("api-umbrella.utils.load_config")()
local hmac = require "resty.nettle.hmac"
local to_hex = require("resty.string").to_hex

local secret_key = assert(config["secret_key"])
local hmac_sha256 = hmac.sha256.new(secret_key)

return function(value)
  hmac_sha256:update(value)
  local binary = hmac_sha256:digest()
  local encoded = to_hex(binary)

  return encoded
end
