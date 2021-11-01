local etlua = require "etlua"

local haproxy_config_template

local path = os.getenv("API_UMBRELLA_SRC_ROOT") .. "/templates/etc/haproxy/haproxy.cfg.etlua"
local f, err = io.open(path, "rb")
if err then
  ngx.log(ngx.ERR, "failed to open file: ", err)
else
  local content = f:read("*all")
  if content then
    local compile_err
    haproxy_config_template, compile_err = etlua.compile(content)
    if compile_err then
      ngx.log(ngx.ERR, "failed to compile haproxy template: ", compile_err)
    end
  end

  f:close()
end

return haproxy_config_template
