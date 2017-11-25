require "api-umbrella.web-app.utils.db_escape_patches"

local Admin = require "api-umbrella.web-app.models.admin"
local db = require "lapis.db"
local escape_html = require("lapis.html").escape
local flash = require "api-umbrella.web-app.utils.flash"
local gettext = require "resty.gettext"
local hmac = require "api-umbrella.utils.hmac"
local is_empty = require("pl.types").is_empty
local lapis = require "lapis"
local lapis_config = require("lapis.config").get()
local path = require "pl.path"
local pg_utils = require "api-umbrella.utils.pg_utils"
local resty_session = require "resty.session"
local session_cipher = require "api-umbrella.web-app.utils.session_cipher"
local session_identifier = require "api-umbrella.web-app.utils.session_identifier"
local session_postgresql_storage = require "api-umbrella.web-app.utils.session_postgresql_storage"

local t = gettext.gettext

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
    self.res.headers["Content-Type"] = "text/html"
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

app.handle_404 = function(self)
  self.res.headers["Content-Type"] = "text/html"
  return self:write({
    status = 404,
    render = "404",
    layout = false,
  })
end

local function current_admin_from_token()
  local current_admin
  local auth_token = ngx.var.http_x_admin_auth_token
  if auth_token then
    local auth_token_hmac = hmac(auth_token)
    local admin = Admin:find({ authentication_token_hash = auth_token_hmac })
    if admin and not admin:is_access_locked() then
      current_admin = admin
    end
  end

  return current_admin
end

local function init_session(self)
  if not self.resty_session then
    self.resty_session = resty_session.new({
      name = "_api_umbrella_session",
      secret = assert(config["secret_key"]),
      random = {
        length = 40,
      },
    })
    self.resty_session.cipher = session_cipher.new(self.resty_session)
    self.resty_session.identifier = session_identifier
    self.resty_session.storage = session_postgresql_storage.new(self.resty_session)
  end
end

local function current_admin_from_session(self)
  local current_admin
  init_session(self)
  self.resty_session:open()
  if self.resty_session and self.resty_session.data and self.resty_session.data["admin_id"] then
    local admin_id = self.resty_session.data["admin_id"]
    local admin = Admin:find({ id = admin_id })
    if admin and not admin:is_access_locked() then
      current_admin = admin
    end
  end

  return current_admin
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

  -- Note that ngx.ctx.pgmoon will only be set after running the db.query
  -- above. If this issue gets addressed there might be a better way to access
  -- the underlying pgmoon object from Lapis:
  -- https://github.com/leafo/lapis/issues/565
  pg_utils.setup_type_casting(ngx.ctx.pgmoon)

  self.t = function(_, message)
    return t(message)
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

  self.init_session = init_session
  local current_admin = current_admin_from_token()
  if not current_admin then
    current_admin = current_admin_from_session(self)
  end
  self.current_admin = current_admin
  ngx.ctx.current_admin = current_admin

  flash.setup(self)
  -- flash.restore(self)
end)

require("api-umbrella.web-app.actions.admin.auth_external")(app)
require("api-umbrella.web-app.actions.admin.passwords")(app)
require("api-umbrella.web-app.actions.admin.registrations")(app)
require("api-umbrella.web-app.actions.admin.server_side_loader")(app)
require("api-umbrella.web-app.actions.admin.sessions")(app)
require("api-umbrella.web-app.actions.admin.stats")(app)
require("api-umbrella.web-app.actions.admin.unlocks")(app)
require("api-umbrella.web-app.actions.v0.analytics")(app)
require("api-umbrella.web-app.actions.v1.admin_groups")(app)
require("api-umbrella.web-app.actions.v1.admin_permissions")(app)
require("api-umbrella.web-app.actions.v1.admins")(app)
require("api-umbrella.web-app.actions.v1.analytics")(app)
require("api-umbrella.web-app.actions.v1.api_scopes")(app)
require("api-umbrella.web-app.actions.v1.apis")(app)
require("api-umbrella.web-app.actions.v1.config")(app)
require("api-umbrella.web-app.actions.v1.contact")(app)
require("api-umbrella.web-app.actions.v1.user_roles")(app)
require("api-umbrella.web-app.actions.v1.users")(app)
require("api-umbrella.web-app.actions.v1.website_backends")(app)

if config["app_env"] == "test" then
  app:get("/api-umbrella/v1/test-500", function()
    error("Testing unexpected raised error")
  end)
end

return app
