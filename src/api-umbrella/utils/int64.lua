local ffi = require "ffi"

ffi.cdef([[
int64_t strtoll(const char* str, char** endptr, int base);
]])

local C = ffi.C
local int64_t = ffi.typeof("int64_t")

local _M = {}

_M.MIN_VALUE = -9223372036854775808LL
_M.MIN_VALUE_STRING = "-9223372036854775808"
_M.MAX_VALUE = 9223372036854775807LL
_M.MAX_VALUE_STRING = "9223372036854775807"

-- The safe range for integers to be converted to JSON:
-- https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Number/MIN_SAFE_INTEGER
--
-- However, note that in order to achieve this range,
-- cjson.encode_number_precision(16) must be called before encoding (the
-- default precision of 14 cannot encode these numbers).
_M.MIN_SAFE_INTEGER = -9007199254740991LL
_M.MAX_SAFE_INTEGER = 9007199254740991LL

function _M.is_64bit(value)
  return ffi.istype(int64_t, value)
end

function _M.to_string(value)
  assert(ffi.istype(int64_t, value))

  -- Remove the "LL" suffix converting to a string normally results in.
  return string.sub(tostring(value), 1, -3)
end

function _M.from_string(value)
  return C.strtoll(value, nil, 10)
end

function _M.to_json_number(value)
  if value == nil then
    return value
  end

  assert(ffi.istype(int64_t, value))

  -- If the 64 bit integer value exceeds the safe JSON range, give a warning.
  -- We'll still go ahead and convert these to numbers, since cjson can still
  -- encode them with scientific notation, but the precision will likely be
  -- lost).
  if value < _M.MIN_SAFE_INTEGER then
    ngx.log(ngx.ERR, "int64 value is less than minimum safe value (" .. _M.to_string(_M.MIN_SAFE_INTEGER) .. "). Precision may be lost in JSON. Value: " .. _M.to_string(value))
  elseif value > _M.MAX_SAFE_INTEGER then
    ngx.log(ngx.ERR, "int64 value is greater than maximum safe value (" .. _M.to_string(_M.MAX_SAFE_INTEGER) .. "). Precision may be lost in JSON. Value: " .. _M.to_string(value))
  end

  return tonumber(value)
end

return _M
