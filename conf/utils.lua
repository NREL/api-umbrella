local _M = {}

local cmsgpack = require "cmsgpack"
local iputils = require "resty.iputils"
local plutils = require "pl.utils"
local types = require "pl.types"

local escape = plutils.escape
local is_empty = types.is_empty
local pack = cmsgpack.pack
local parse_cidrs = iputils.parse_cidrs
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
    base = base .. ":" .. port
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
  for key, value in pairs(src) do
    if type(value) == "table" and type(dest[key]) == "table" then
      if _M.is_array(value) then
        dest[key] = value
      else
        merge(dest[key], src[key])
      end
    else
      dest[key] = value
    end
  end

  return dest
end

function _M.cache_computed_settings(settings)
  if not settings then return end

  if settings["url_matches"] then
    for _, url_match in ipairs(settings["url_matches"]) do
      url_match["_frontend_prefix_matcher"] = "^" .. escape(url_match.frontend_prefix)
    end
  end

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

return _M
