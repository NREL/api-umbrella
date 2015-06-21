local cjson = require "cjson"

local path = "/vagrant/lua-integration/config/user_agent_data.json"
local f, err = io.open(path, "rb")
if err then
  ngx.log(ngx.ERR, "failed to open file: ", err)
else
  local content = f:read("*all")
  if content then
    local ok, data = pcall(cjson.decode, content)
    if ok then
      user_agent_parser_data = data
    else
      ngx.log(ngx.ERR, "failed to parse json for ", path)
    end
  end

  f:close()
end
