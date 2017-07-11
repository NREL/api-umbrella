inspect = require "inspect"
config = require "api-umbrella.proxy.models.file_config"

local get_api_umbrella_version = require "api-umbrella.utils.get_api_umbrella_version"
API_UMBRELLA_VERSION = get_api_umbrella_version()

local dir = require "pl.dir"
local path = require "pl.path"
local login_css_paths = dir.getfiles(path.join(config["_embedded_root_dir"], "apps/core/current/build/dist/admin-auth-assets"), "login-*.css")
if login_css_paths and #login_css_paths == 1 then
  LOGIN_CSS_FILENAME = path.basename(login_css_paths[1])
else
  ngx.log(ngx.ERR, "could not find login css file path")
end
