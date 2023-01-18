require("api-umbrella.utils.load_config")()

local migrations = require("migrations")
local pg_utils = require "api-umbrella.utils.pg_utils"

return function()
  for key, _ in pairs(migrations) do
    local printed = false
    repeat
      local result = pg_utils.query("SELECT 1 FROM lapis_migrations WHERE name = :name", { name = tostring(key) }, { verbose = false, fatal = true })
      if #result == 0 then
        if not printed then
          print("Waiting for migration '" .. key .. "'")
          printed = true
        end

        ngx.sleep(0.5)
      end
    until #result > 0
  end

  print("Migrations up to date")
end
