inspect = require "inspect"
local lapis = require "lapis"
local db = require "lapis.db"

local app = lapis.Application()

app:before_filter(function()
  db.query("SET application.name = 'admin'")
  db.query("SET application.\"user\" = 'admin'")
end)

require("api-umbrella.lapis.actions.v1.api_scopes")(app)

return app
