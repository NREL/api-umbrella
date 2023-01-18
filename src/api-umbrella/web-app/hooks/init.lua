require "config"
require "lapis.features.etlua"
require "api-umbrella.web-app.utils.db_escape_patches"

-- Pre-load modules.
require "api-umbrella.web-app.hooks.init_preload_modules"

local worker_group_init = require("api-umbrella.utils.worker_group").init
worker_group_init()

local basename = require("posix.libgen").basename
local config = require("api-umbrella.utils.load_config")()
local find_cmd = require "api-umbrella.utils.find_cmd"
local json_decode = require("cjson").decode
local path_join = require "api-umbrella.utils.path_join"
local readfile = require("pl.utils").readfile

local get_api_umbrella_version = require "api-umbrella.utils.get_api_umbrella_version"
API_UMBRELLA_VERSION = get_api_umbrella_version()

local login_css_paths = find_cmd(path_join(config["_embedded_root_dir"], "app/build/dist/web-assets"), { "-name", "login-*.css" })
if login_css_paths and #login_css_paths == 1 then
  LOGIN_CSS_FILENAME = basename(login_css_paths[1])
else
  ngx.log(ngx.ERR, "could not find login css file path")
end

local login_js_paths = find_cmd(path_join(config["_embedded_root_dir"], "app/build/dist/web-assets"), { "-name", "login-*.js" })
if login_js_paths and #login_js_paths == 1 then
  LOGIN_JS_FILENAME = basename(login_js_paths[1])
else
  ngx.log(ngx.ERR, "could not find login js file path")
end

LOCALE_DATA = {}
local locale_paths = find_cmd(path_join(config["_embedded_root_dir"], "app/build/dist/locale"), { "-name", "*.json" })
for _, locale_path in ipairs(locale_paths) do
  local data = json_decode(readfile(locale_path))
  local lang = data["locale_data"]["api-umbrella"][""]["lang"]
  LOCALE_DATA[lang] = data
end
