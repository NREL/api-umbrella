local split = require("ngx.re").split

local _M = {}

function _M.parse_quality_factor(header)
  if not header then
    return nil
  end

  local parsed = {}

  -- Split the header into different types.
  --
  -- "text/html, application/xml;q=0.9"
  -- =>
  -- { "text/html", "application/xml;q=0.9" }
  local types, types_err = split(header, [[ *, *]], "jo")
  if types_err then
    ngx.log(ngx.ERR, "regex error: ", types_err)
    return nil
  end
  for index, type_string in ipairs(types) do
    -- Split the type to separate the value from optional parameters.
    --
    -- "text/html;level=2;q=0.4"
    -- =>
    -- { "text/html", "level=2", "q=0.4" }
    local type_parts, type_parts_err = split(type_string, [[ *; *]], "jo")
    if type_parts_err then
      ngx.log(ngx.ERR, "regex error: ", type_parts_err)
      return nil
    end
    local value = type_parts[1]

    -- If parameters are present, then search them for a quality factor
    -- (otherwise, the default quality factor is 1).
    local q = 1
    if type_parts[2] then
      for i = 2, #type_parts do
        local param = type_parts[i]
        local param_parts, param_parts_err = split(param, [[ *= *]], "jo")
        if param_parts_err then
          ngx.log(ngx.ERR, "regex error: ", param_parts_err)
          return nil
        end
        local param_key = param_parts[1]
        local param_value = param_parts[2]
        if param_key == "q" then
          q = tonumber(param_value) or 0
        end
      end
    end

    -- Skip any values with a quality factor of 0.
    if q == 0 then
      break
    end

    table.insert(parsed, {
      value = value,
      q = q,
      original_index = index,
    })
  end

  -- Sort the types by the quality factor.
  table.sort(parsed, function(a, b)
    if a["q"] < b["q"] then
      return false
    elseif a["q"] > b["q"] then
      return true
    else
      return a["original_index"] < b["original_index"]
    end
  end)

  return parsed
end

function _M.parse_accept(header)
  local parsed = _M.parse_quality_factor(header)
  if parsed then
    for _, accepted in ipairs(parsed) do
      local media_parts, media_parts_err = split(accepted["value"], [[ */ *]], "jo", nil, 2)
      if media_parts_err then
        ngx.log(ngx.ERR, "regex error: ", media_parts_err)
        return nil
      end
      accepted["media_type"] = media_parts[1]
      accepted["media_subtype"] = media_parts[2]
    end

    -- Re-sort, taking into account wildcard media types to break quality factor
    -- ties.
    table.sort(parsed, function(a, b)
      if a["q"] < b["q"] then
        return false
      elseif a["q"] > b["q"] then
        return true
      elseif (a["media_type"] == "*" and b["media_type"] ~= "*") or (a["media_subtype"] == "*" and b["media_subtype"] ~= "*") then
        return false
      elseif (a["media_type"] ~= "*" and b["media_type"] == "*") or (a["media_subtype"] ~= "*" and b["media_subtype"] == "*") then
        return true
      else
        return a["original_index"] < b["original_index"]
      end
    end)
  end

  return parsed
end

function _M.preferred_accept(header, supported_media_types)
  local parsed = _M.parse_accept(header)
  if parsed and supported_media_types then
    for _, accepted in ipairs(parsed) do
      for _, supported in ipairs(supported_media_types) do
        if accepted["media_type"] == supported["media_type"] and accepted["media_subtype"] == supported["media_subtype"] then
          return supported
        elseif accepted["media_type"] == supported["media_type"] and accepted["media_subtype"] == "*" then
          return supported
        elseif accepted["media_type"] == "*" and accepted["media_subtype"] == "*" then
          return supported
        end
      end
    end
  end
end

function _M.parse_accept_language(header)
  local parsed = _M.parse_quality_factor(header)
  if parsed then
    for _, accepted in ipairs(parsed) do
      accepted["value_lower"] = string.lower(accepted["value"])

      local lang_parts, lang_parts_err = split(accepted["value"], [[-]], "jo", nil, 2)
      if lang_parts_err then
        ngx.log(ngx.ERR, "regex error: ", lang_parts_err)
        return nil
      end
      accepted["lang"] = string.lower(lang_parts[1])
      if lang_parts[2] then
        accepted["country"] = string.upper(lang_parts[2])
      end
    end
  end

  return parsed
end

function _M.preferred_accept_language(header, supported_languages)
  local preferred

  local parsed = _M.parse_accept_language(header)
  if parsed and supported_languages then
    -- Loop over all the acceptable languages in order of the client's
    -- preference.
    for _, accepted in ipairs(parsed) do
      -- See if any of the supported languages match the client's accepted
      -- language.
      for _, supported in ipairs(supported_languages) do
        local supported_lower = string.lower(supported)

        -- If there's an exact match, return it immediately.
        if accepted["value_lower"] == supported_lower then
          preferred = supported
          break

        -- If there's a match only on the base language (but not including the
        -- country), then remember this match, but keep looping to see if
        -- there's an exact match.
        elseif accepted["lang"] == supported_lower then
          preferred = supported
        end
      end

      if preferred then
        break
      end
    end
  end

  return preferred
end

return _M
