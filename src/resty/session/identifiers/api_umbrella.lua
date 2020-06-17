local random_token = require "api-umbrella.utils.random_token"

local defaults = {
  length = 40
}

return function(session)
  local config = session.random or defaults
  local length = tonumber(config.length, 10) or defaults.length
  return random_token(length)
end
