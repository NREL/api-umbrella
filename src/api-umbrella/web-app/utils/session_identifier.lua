local random_token = require "api-umbrella.utils.random_token"

local defaults = {
  length = 40
}

return function(config)
  local c = config.random or defaults
  local l = c.length or defaults.length
  return random_token(l)
end
