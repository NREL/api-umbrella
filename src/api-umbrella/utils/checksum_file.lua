local resty_sha256 = require "resty.sha256"
local to_hex = require("resty.string").to_hex

local _M = {}

function _M.sha256(file_path)
  local sha256 = resty_sha256:new()

  local file, err = io.open(file_path, "rb")
  if err then
    return nil, err
  end

  repeat
    local chunk = file:read(8192)
    if chunk then
      sha256:update(chunk)
    end
  until not chunk

  return to_hex(sha256:final())
end

return _M
