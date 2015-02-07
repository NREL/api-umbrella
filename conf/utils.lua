local _M = {}

local cmsgpack = require "cmsgpack"
local inspect = require "inspect"
local iputils = require "resty.iputils"
local plutils = require "pl.utils"
local stringx = require "pl.stringx"
local types = require "pl.types"

local escape = plutils.escape
local is_empty = types.is_empty
local pack = cmsgpack.pack
local parse_cidrs = iputils.parse_cidrs
local split = plutils.split
local strip = stringx.strip
local unpack = cmsgpack.unpack

-- Determine if the table is an array.
--
-- In benchmarks, appears faster than moses.isArray implementation.
function _M.is_array(obj)
  if type(obj) ~= "table" then return false end

  local count = 1
  for key, _ in pairs(obj) do
    if key ~= count then
      return false
    end
    count = count + 1
  end

  return true
end

-- Append an array to the end of the destination array.
--
-- In benchmarks, appears faster than moses.append and pl.tablex.move
-- implementations.
function _M.append_array(dest, src)
  if type(dest) ~= "table" or type(src) ~= "table" then return end

  dest_length = #dest
  src_length = #src
  for i=1, src_length do
    dest[dest_length + i] = src[i]
  end

  return dest
end

function _M.base_url()
  local protocol = ngx.ctx.protocol
  local host = ngx.ctx.host
  local port = ngx.ctx.port

  local base = protocol .. "://" .. host
  if (protocol == "http" and port ~= "80") or (protocol == "https" and port ~= "443") then
    if not host:find(":" .. port .. "$") then
      base = base .. ":" .. port
    end
  end

  return base
end

function _M.get_packed(dict, key)
  local packed = dict:get(key)
  if packed then
    return unpack(packed)
  end
end

function _M.set_packed(dict, key, value)
  return dict:set(key, pack(value))
end

function _M.deep_merge_overwrite_arrays(dest, src)
  if not src then
    return dest
  end

  for key, value in pairs(src) do
    if type(value) == "table" and type(dest[key]) == "table" then
      if _M.is_array(value) then
        dest[key] = value
      else
        _M.deep_merge_overwrite_arrays(dest[key], src[key])
      end
    else
      dest[key] = value
    end
  end

  return dest
end

function _M.cache_computed_settings(settings)
  if not settings then return end

  -- Parse and cache the allowed IPs as CIDR ranges.
  if not is_empty(settings["allowed_ips"]) then
    settings["_allowed_cidrs"] = parse_cidrs(settings["allowed_ips"])
    settings["allowed_ips"] = nil
  end

  -- Parse and cache the allowed referers as matchers
  if not is_empty(settings["allowed_referers"]) then
    settings["_allowed_referer_matchers"] = {}
    for _, referer in ipairs(settings["allowed_referers"]) do
      local matcher = escape(referer)
      matcher = string.gsub(matcher, "%%%*", ".*")
      matcher = "^" .. matcher .. "$"
      table.insert(settings["_allowed_referer_matchers"], matcher)
    end
    settings["allowed_referers"] = nil
  end

  if settings["append_query_string"] then
    settings["_append_query_args"] = ngx.decode_args(settings["append_query_string"])
    settings["append_query_string"] = nil
  end

  if settings["http_basic_auth"] then
    settings["_http_basic_auth_header"] = "Basic " .. ngx.encode_base64(settings["http_basic_auth"])
    settings["http_basic_auth"] = nil
  end
end

function _M.parse_accept(header, supported_media_types)
  if not header then
    return nil
  end

  local accepts = {}
  local accept_header = split(header, ",")
  for _, accept_string in ipairs(accept_header) do
    local parts = split(accept_string, ";", 2)
    local media = parts[1]
    local params = parts[2]
    if params then
      params = split(params, ";")
    end

    local media_parts = split(media, "/")
    local media_type = strip(media_parts[1] or "")
    local media_subtype = strip(media_parts[2] or "")

    local q = 1
    for _, param in ipairs(params) do
      local param_parts = split(param, "=")
      local param_key = strip(param_parts[1] or "")
      local param_value = strip(param_parts[2] or "")
      if param_key == "q" then
        q = tonumber(param_value)
      end
    end

    if q == 0 then
      break
    end

    local accept = {
      media_type = media_type,
      media_subtype = media_subtype,
      q = q,
    }

    table.insert(accepts, accept)
  end

  table.sort(accepts, function(a, b)
    if a.q < b.q then
      return false
    elseif a.q > b.q then
      return true
    elseif (a.media_type == "*" and b.media_type ~= "*") or (a.media_subtype == "*" and b.media_subtype ~= "*") then
      return false
    elseif (a.media_type ~= "*" and b.media_type == "*") or (a.media_subtype ~= "*" and b.media_subtype == "*") then
      return true
    else
      return true
    end
  end)

  for _, supported in ipairs(supported_media_types) do
    for _, accept in ipairs(accepts) do
      if accept.media_type == supported.media_type and accept.media_subtype == supported.media_subtype then
        return supported.format
      elseif accept.media_type == supported.media_type and accept.media_subtype == "*" then
        return supported.format
      elseif accept.media_type == "*" and accept.media_subtype == "*" then
        return supported.format
      else
        return nil
      end
    end
  end
end

return _M
