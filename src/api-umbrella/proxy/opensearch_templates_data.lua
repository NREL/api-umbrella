local config = require("api-umbrella.utils.load_config")()
local etlua_render = require("etlua").render
local json_decode = require("cjson").decode
local json_encode = require "api-umbrella.utils.json_encode"
local xpcall_error_handler = require "api-umbrella.utils.xpcall_error_handler"

local opensearch_templates

local path = os.getenv("API_UMBRELLA_SRC_ROOT") .. "/config/opensearch_templates_v" .. config["opensearch"]["template_version"] .. ".json.etlua"
local f, err = io.open(path, "rb")
if err then
  ngx.log(ngx.ERR, "failed to open file: ", err)
else
  local content = f:read("*all")
  if content then
    local render_ok, render_err
    render_ok, content, render_err = xpcall(etlua_render, xpcall_error_handler, content, { config = config, json_encode = json_encode })
    if not render_ok or render_err then
      ngx.log(ngx.ERR, "template compile error in " .. path ..": " .. (render_err or content))
    end

    local ok, data = xpcall(json_decode, xpcall_error_handler, content)
    if ok then
      opensearch_templates = data
    else
      ngx.log(ngx.ERR, "failed to parse json for " .. (path or "") .. ": " .. (data or ""))
    end
  end

  f:close()
end

return opensearch_templates
