local hmac = require "resty.nettle.hmac"
local to_hex = require("resty.string").to_hex

local secret_key = config["web"]["rails_secret_token"]
local hmac_sha256 = hmac.sha256.new(secret_key)

return function(value)
  hmac_sha256:update(value)
  local binary = hmac_sha256:digest()
  local encoded = to_hex(binary)

  return encoded
end
