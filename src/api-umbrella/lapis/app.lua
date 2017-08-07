local Admin = require "api-umbrella.lapis.models.admin"
local db = require "lapis.db"
local escape_html = require("lapis.html").escape
local flash = require "api-umbrella.utils.lapis_flash"
local gettext = require "resty.gettext"
local hmac = require "api-umbrella.utils.hmac"
local is_empty = require("pl.types").is_empty
local lapis = require "lapis"
local path = require "pl.path"

gettext.bindtextdomain("api-umbrella", path.join(config["_embedded_root_dir"], "apps/core/current/build/dist/locale"))
gettext.textdomain("api-umbrella")

local app = lapis.Application()
app:enable("etlua")
app.layout = require "views.layout"

app:before_filter(function(self)
  local ok = os.setlocale("fr_FR")
  if not ok then
    ngx.log(ngx.ERR, "setlocale failed")
  end

  db.query("SET application.name = 'admin'")
  db.query("SET application.\"user\" = 'admin'")

  self.t = function(_, message)
    return gettext.gettext(message)
  end

  self.field_errors = function(_, field)
    if self.errors and not is_empty(self.errors[field]) then
      table.sort(self.errors[field])
      return '<span class="help-block">' .. escape_html(table.concat(self.errors[field], ", ")) .. "</span>"
    else
      return ""
    end
  end

  self.field_errors_class = function(_, field)
    if self.errors and not is_empty(self.errors[field]) then
      return " has-error"
    else
      return ""
    end
  end

  local current_admin
  local auth_token = ngx.var.http_x_admin_auth_token
  if auth_token then
    local auth_token_hmac = hmac(auth_token)
    ngx.log(ngx.ERR, "AUTH_TOKEN: " .. inspect(auth_token))
    ngx.log(ngx.ERR, "AUTH_TOKEN hmac: " .. inspect(auth_token_hmac))
    local admin = Admin:find({ authentication_token_hash = auth_token_hmac })
    if admin and not admin:is_access_locked() then
      current_admin = admin
    end
  end
  self.current_admin = current_admin


  flash.setup(self)
  -- flash.restore(self)
end)

require("api-umbrella.lapis.actions.admin.sessions")(app)
require("api-umbrella.lapis.actions.admin.registrations")(app)
require("api-umbrella.lapis.actions.admin.passwords")(app)
require("api-umbrella.lapis.actions.admin.unlocks")(app)
require("api-umbrella.lapis.actions.admin.server_side_loader")(app)
require("api-umbrella.lapis.actions.v1.admins")(app)
require("api-umbrella.lapis.actions.v1.admin_groups")(app)
require("api-umbrella.lapis.actions.v1.admin_permissions")(app)
require("api-umbrella.lapis.actions.v1.api_scopes")(app)
require("api-umbrella.lapis.actions.v1.users")(app)

return app
