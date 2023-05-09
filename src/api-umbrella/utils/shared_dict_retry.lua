local RETRIES = 5

-- Retry calling `set` and `incr` multiple times when "no memory" errors are
-- returned to try and deal with memory fragmentation issues:
-- https://github.com/thibaultcha/lua-resty-mlcache/blob/2.6.0/lib/resty/mlcache.lua#L485-L501

local _M = {}

function _M.set(dict, key, value, exptime, flags)
  local tries = 0
  local ok, err, forcible

  while tries < RETRIES do
    tries = tries + 1

    ok, err, forcible = dict:set(key, value, exptime, flags or 0)
    if ok or err and err ~= "no memory" then
      break
    end
  end

  return ok, err, forcible
end

function _M.incr(dict, key, value, init, init_ttl)
  if init ~= nil and init_ttl == nil then
    init_ttl = 0
  end

  local tries = 0
  local newval, err, forcible

  while tries < RETRIES do
    tries = tries + 1

    newval, err, forcible = dict:incr(key, value, init, init_ttl)
    if newval or err and err ~= "no memory" then
      break
    end
  end

  return newval, err, forcible
end

return _M
