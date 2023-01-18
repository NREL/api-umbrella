local config = require("api-umbrella.utils.load_config")()
local json_encode = require "api-umbrella.utils.json_encode"

return function()
  print(json_encode(config))
end
