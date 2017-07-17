local db = require "lapis.db"
local gettext = require "resty.gettext"
local lapis = require "lapis"
local path = require "pl.path"

gettext.bindtextdomain("api-umbrella", path.join(config["_src_root_dir"], "config/locale"))
gettext.textdomain("api-umbrella")

local ok = os.setlocale("fr_FR")
if not ok then
  ngx.log(ngx.ERR, "setlocale failed")
end

local app = lapis.Application()
app:enable("etlua")
app.layout = require "views.layout"

app:before_filter(function()
  db.query("SET application.name = 'admin'")
  db.query("SET application.\"user\" = 'admin'")
end)

require("api-umbrella.lapis.actions.admin.sessions")(app)
require("api-umbrella.lapis.actions.admin.registrations")(app)
require("api-umbrella.lapis.actions.v1.admins")(app)
require("api-umbrella.lapis.actions.v1.admin_groups")(app)
require("api-umbrella.lapis.actions.v1.admin_permissions")(app)
require("api-umbrella.lapis.actions.v1.api_scopes")(app)
require("api-umbrella.lapis.actions.v1.users")(app)

return app
