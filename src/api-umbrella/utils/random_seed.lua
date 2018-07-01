local random_bytes = require("resty.random").bytes

-- Seed math.randomseed based on random bytes from openssl. This is better than
-- relying on something like os.time(), since that can result in identical
-- seeds for multiple workers started up at the same time.
--
-- Based on https://github.com/bungle/lua-resty-random/blob/17b604f7f7dd217557ca548fc1a9a0d373386480/lib/resty/random.lua#L49-L52
local function seed()
  local num_bytes = 4
  local random = random_bytes(num_bytes, true)
  if not random then
    ngx.log(ngx.WARN, "Could not generate cryptographically secure random data for seeding math.randomseed. Falling back to non-secure random data.")
    random = random_bytes(num_bytes, false)
  end

  local byte1, byte2, byte3, byte4 = string.byte(random, 1, 4)
  local randomseed = byte1 * 0x1000000 + byte2 * 0x10000 + byte3 * 0x100 + byte4

  return math.randomseed(randomseed)
end

seed()

return seed
