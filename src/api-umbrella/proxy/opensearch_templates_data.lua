local config = require("api-umbrella.utils.load_config")()
local etlua_render = require("etlua").render
local json_decode = require("cjson").decode
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
    render_ok, content, render_err = xpcall(etlua_render, xpcall_error_handler, content, { config = config })
    if not render_ok or render_err then
      ngx.log(ngx.ERR, "template compile error in " .. path ..": " .. (render_err or content))
    end

    local ok, data = xpcall(json_decode, xpcall_error_handler, content)
    if ok then
      opensearch_templates = data

      -- In the test environment, disable replicas and reduce shards to speed
      -- things up.
      if config["app_env"] == "test" then
        for _, template in pairs(opensearch_templates) do
          if not template["template"]["settings"] then
            template["template"]["settings"] = {}
          end
          if not template["template"]["settings"]["index"] then
            template["template"]["settings"]["index"] = {}
          end

          template["template"]["settings"]["index"]["number_of_shards"] = 1
          template["template"]["settings"]["index"]["number_of_replicas"] = 0
        end
      end
    else
      ngx.log(ngx.ERR, "failed to parse json for " .. (path or "") .. ": " .. (data or ""))
    end
  end

  f:close()
end

return opensearch_templates
