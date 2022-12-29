local _M = {}

_M.context_delimiter = string.char(4)

-- Based on Jed's implementation of gettext:
-- https://github.com/messageformat/Jed/blob/351c47d5c57c5c81e418414c53ca84075c518edb/jed.js#L216
--
-- This implementation allows us to re-use the same JSON output we will send to
-- Jed for client-side translations. This implementation also handles
-- concurrent requests in different locales properly (unlike native gettext
-- solutions using the C library), by using a request-specific variable
-- (ngx.ctx) for determining the current locale.
function _M.dcnpgettext(domain, context, singular_key, plural_key, count)
  if not domain then
    domain = "api-umbrella"
  end

  local data
  local locale = ngx.ctx.locale
  if locale and LOCALE_DATA and LOCALE_DATA[locale] and LOCALE_DATA[locale]["locale_data"] and LOCALE_DATA[locale]["locale_data"][domain] then
    data = LOCALE_DATA[locale]["locale_data"][domain]
  else
    data = {}
  end

  if not plural_key then
    plural_key = singular_key
  end

  local key
  if context then
    key = context .. _M.context_delimiter .. singular_key
  else
    key = singular_key
  end

  local value_index
  if count then
    assert(type(count) == "number")
    return error("TODO: plural gettext support")
  else
    value_index = 1
  end

  local value_list = data[key]
  if value_list and value_list[value_index] then
    return value_list[value_index]
  else
    -- TODO: plural gettext support
    local defaults = { singular_key, plural_key }
    return defaults[value_index]
  end
end

function _M.gettext(key)
  return _M.dcnpgettext(nil, nil, key)
end

return _M
