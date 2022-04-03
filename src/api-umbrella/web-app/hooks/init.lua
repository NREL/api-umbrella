require "config"
require "lapis.features.etlua"
require "api-umbrella.web-app.utils.db_escape_patches"

-- Pre-load modules.
require "api-umbrella.web-app.hooks.init_preload_modules"

local worker_group_init = require("api-umbrella.utils.worker_group").init
worker_group_init()

local config = require "api-umbrella.proxy.models.file_config"
local dir_getfiles = require("pl.dir").getfiles
local file_read = require("pl.file").read
local json_decode = require("cjson").decode
local path = require "pl.path"

local get_api_umbrella_version = require "api-umbrella.utils.get_api_umbrella_version"
API_UMBRELLA_VERSION = get_api_umbrella_version()

local login_css_paths = dir_getfiles(path.join(config["_embedded_root_dir"], "app/build/dist/web-assets"), "login-*.css")
if login_css_paths and #login_css_paths == 1 then
  LOGIN_CSS_FILENAME = path.basename(login_css_paths[1])
else
  ngx.log(ngx.ERR, "could not find login css file path")
end

local login_js_paths = dir_getfiles(path.join(config["_embedded_root_dir"], "app/build/dist/web-assets"), "login-*.js")
if login_js_paths and #login_js_paths == 1 then
  LOGIN_JS_FILENAME = path.basename(login_js_paths[1])
else
  ngx.log(ngx.ERR, "could not find login js file path")
end

LOCALE_DATA = {}
local locale_paths = dir_getfiles(path.join(config["_embedded_root_dir"], "app/build/dist/locale"), "*.json")
for _, locale_path in ipairs(locale_paths) do
  local data = json_decode(file_read(locale_path))
  local lang = data["locale_data"]["api-umbrella"][""]["lang"]
  LOCALE_DATA[lang] = data
end
