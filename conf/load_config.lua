local _M = {}

local lyaml = require "lyaml"
local cjson = require "cjson"
local moses = require "moses"
local utils = require "pl.utils"
local log = ngx.log
local ERR = ngx.ERR

function _M.parse()
  local f, err = io.open("/tmp/runtime_config.yml", "rb")
  if err then
    return log(ERR, "failed to open config file: ", err)
  end

  local content = f:read("*all")
  f:close()

  local data = lyaml.load(content)

  return data
end

return _M
