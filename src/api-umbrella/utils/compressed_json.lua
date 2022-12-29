local json_decode = require("cjson").decode
local json_encode = require "api-umbrella.utils.json_encode"
local zstandard = require "zstd"

local zstd = zstandard:new()

local _M = {}

function _M.compress_json_encode(value)
  local json_string = json_encode(value)
  local compressed = zstd:compress(json_string)
  return compressed
end

function _M.decompress_json_decode(compressed)
  local json_string = zstd:decompress(compressed)
  local value = json_decode(json_string)
  return value
end

return _M
