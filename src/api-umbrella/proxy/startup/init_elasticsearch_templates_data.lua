local cjson = require "cjson"
local xpcall_error_handler = require "api-umbrella.utils.xpcall_error_handler"

local path = os.getenv("API_UMBRELLA_SRC_ROOT") .. "/config/elasticsearch_templates_" .. config["log_template_version"] .. ".json"
local f, err = io.open(path, "rb")
if err then
  ngx.log(ngx.ERR, "failed to open file: ", err)
else
  local content = f:read("*all")
  if content then
    local ok, data = xpcall(cjson.decode, xpcall_error_handler, content)
    if ok then
      elasticsearch_templates = data
    else
      ngx.log(ngx.ERR, "failed to parse json for " .. (path or "") .. ": " .. (data or ""))
    end
  end

  f:close()
end
