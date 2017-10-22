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

return _M
