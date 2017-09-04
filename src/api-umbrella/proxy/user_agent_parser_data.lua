local cjson = require "cjson"
local xpcall_error_handler = require "api-umbrella.utils.xpcall_error_handler"

local user_agent_parser_data

local path = os.getenv("API_UMBRELLA_SRC_ROOT") .. "/config/user_agent_data.json"
local f, err = io.open(path, "rb")
if err then
  ngx.log(ngx.ERR, "failed to open file: ", err)
else
  local content = f:read("*all")
  if content then
    local ok, data = xpcall(cjson.decode, xpcall_error_handler, content)
    if ok then
      user_agent_parser_data = data
    else
      ngx.log(ngx.ERR, "failed to parse json for " .. (path or "") .. ": " .. (data or ""))
    end
  end

  f:close()
end

return user_agent_parser_data
