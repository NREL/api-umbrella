local Admin = require "api-umbrella.lapis.models.admin"
local db = require "lapis.db"
local escape_html = require("lapis.html").escape
local flash = require "api-umbrella.utils.lapis_flash"
local gettext = require "resty.gettext"
local hmac = require "api-umbrella.utils.hmac"
local is_empty = require("pl.types").is_empty
local lapis = require "lapis"
local lapis_config = require("lapis.config").get()
local path = require "pl.path"

gettext.bindtextdomain("api-umbrella", path.join(config["_embedded_root_dir"], "apps/core/current/build/dist/locale"))
gettext.textdomain("api-umbrella")

local app = lapis.Application()
app:enable("etlua")
app.layout = require "views.layout"

-- Custom error handler so we only show the default lapis debug details in
-- development, and a generic error page in production.
app.handle_error = function(self, err, trace)
  ngx.log(ngx.ERR, "Unexpected error: " .. (err or "") .. "\n" .. (trace or ""))

  if lapis_config.show_errors then
    return lapis.Application.handle_error(self, err, trace)
  else
    return {
      status = 500,
      render = "500",
      layout = false,
    }
  end
end

-- Override the default render_error_request so that backtraces aren't output
-- as an HTTP header in the test enivironment. This lets us verify that no
-- backtraces are output, even in the test environment (so we can have tests
-- around what will happen with error handling in production).
app.render_error_request = function(self, r, err, trace)
  r:write(self.handle_error(r, err, trace))
  return self:render_request(r)
end

app.handle_404 = function()
  return {
    status = 404,
    render = "404",
    layout = false,
  }
end

app:before_filter(function(self)
  -- local ok = os.setlocale("fr_FR")
  -- if not ok then
  --   ngx.log(ngx.ERR, "setlocale failed")
  -- end

  self.res.headers["Cache-Control"] = "max-age=0, private, must-revalidate"

  -- Set session variables for the database connection (always use UTC and set
  -- an app name for auditing).
  --
  -- Ideally we would only set these once per connection (and not set it when
  -- the socket is reused), but Lapi's "db" instance doesn't have a way to get
  -- the underlying pgmoon connection before executing a query (the connection
  -- is lazily established after the first query).
  db.query("SET SESSION application_name = 'api-umbrella-web-app'")
  db.query("SET SESSION timezone = 'UTC'")

  -- pgmoon is currently missing support for handling PostgreSQL inet array
  -- types, so it doesn't know how to decode/encode these. So manually add
  -- inet[]'s oid (1041) so that they're handled as an array of strings.
  --
  -- Note that ngx.ctx.pgmoon will only be set after running the db.querys
  -- above. If this issue gets addressed there might be a better way to access
  -- the underlying pgmoon object from Lapis:
  -- https://github.com/leafo/lapis/issues/565
  ngx.ctx.pgmoon:set_type_oid(1041, "array_string")

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
  ngx.ctx.current_admin = current_admin

  flash.setup(self)
  -- flash.restore(self)
end)

require("api-umbrella.lapis.actions.admin.passwords")(app)
require("api-umbrella.lapis.actions.admin.registrations")(app)
require("api-umbrella.lapis.actions.admin.server_side_loader")(app)
require("api-umbrella.lapis.actions.admin.sessions")(app)
require("api-umbrella.lapis.actions.admin.unlocks")(app)
require("api-umbrella.lapis.actions.v1.admin_groups")(app)
require("api-umbrella.lapis.actions.v1.admin_permissions")(app)
require("api-umbrella.lapis.actions.v1.admins")(app)
require("api-umbrella.lapis.actions.v1.api_scopes")(app)
require("api-umbrella.lapis.actions.v1.apis")(app)
require("api-umbrella.lapis.actions.v1.config")(app)
require("api-umbrella.lapis.actions.v1.user_roles")(app)
require("api-umbrella.lapis.actions.v1.users")(app)

if config["app_env"] == "test" then
  app:get("/api-umbrella/v1/test-500", function()
    error("Testing unexpected raised error")
  end)
end

return app
