local random_token = require "api-umbrella.utils.random_token"

local defaults = {
  length = tonumber(ngx.var.session_random_length) or 40
}

return function(config)
  local c = config.random or defaults
  local l = c.length or defaults.length
  return random_token(l)
end
