local _M = {}

local cjson = require "cjson"
local cmsgpack = require "cmsgpack"
local plutils = require "pl.utils"
local stringx = require "pl.stringx"
local tablex = require "pl.tablex"
local types = require "pl.types"

local escape = plutils.escape
local gsub = ngx.re.gsub
local is_empty = types.is_empty
local json_null = cjson.null
local pack = cmsgpack.pack
local split = plutils.split
local strip = stringx.strip
local table_keys = tablex.keys
local unpack = cmsgpack.unpack

-- Append an array to the end of the destination array.
--
-- In benchmarks, appears faster than moses.append and pl.tablex.move
-- implementations.
function _M.append_array(dest, src)
  if type(dest) ~= "table" or type(src) ~= "table" then return end

  local dest_length = #dest
  local src_length = #src
  for i=1, src_length do
    dest[dest_length + i] = src[i]
  end

  return dest
end

function _M.base_url()
  local ngx_ctx = ngx.ctx
  local protocol = ngx_ctx.protocol
  local host = ngx_ctx.host
  local port = ngx_ctx.port

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

function _M.pick_where_present(dict, keys)
  local selected = {}

  if type(dict) == "table" and type(keys) == "table" then
    for _, key in ipairs(keys) do
      if dict[key] and dict[key] ~= false and dict[key] ~= json_null and not is_empty(dict[key]) then
        selected[key] = dict[key]
      end
    end
  end

  return selected
end

function _M.cache_computed_settings(settings)
  if not settings then return end

  -- Parse and cache the allowed IPs as CIDR ranges.
  if not is_empty(settings["allowed_ips"]) then
    settings["_allowed_ips"] = settings["allowed_ips"]
  end
  settings["allowed_ips"] = nil

  -- Parse and cache the allowed referers as matchers
  if not is_empty(settings["allowed_referers"]) then
    settings["_allowed_referer_matchers"] = {}
    for _, referer in ipairs(settings["allowed_referers"]) do
      local matcher = escape(referer)
      matcher = string.gsub(matcher, "%%%*", ".*")
      matcher = "^" .. matcher .. "$"
      table.insert(settings["_allowed_referer_matchers"], matcher)
    end
  end
  settings["allowed_referers"] = nil

  if not is_empty(settings["headers"]) then
    settings["_headers"] = {}
    for _, header in ipairs(settings["headers"]) do
      if header["value"] and string.find(header["value"], "{{") then
        header["_process_as_template"] = true
      end

      table.insert(settings["_headers"], header)
    end
  end
  settings["headers"] = nil

  if not is_empty(settings["default_response_headers"]) then
    settings["_default_response_headers"] = settings["default_response_headers"]
  end
  settings["default_response_headers"] = nil

  if not is_empty(settings["override_response_headers"]) then
    settings["_override_response_headers"] = settings["override_response_headers"]
  end
  settings["override_response_headers"] = nil

  if not is_empty(settings["append_query_string"]) then
    settings["_append_query_arg_names"] = table_keys(ngx.decode_args(settings["append_query_string"]))
  elseif settings["append_query_string"] then
    settings["append_query_string"] = nil
  end

  if not is_empty(settings["http_basic_auth"]) then
    settings["_http_basic_auth_header"] = "Basic " .. ngx.encode_base64(settings["http_basic_auth"])
  end
  settings["http_basic_auth"] = nil

  if settings["api_key_verification_transition_start_at"] and settings["api_key_verification_transition_start_at"]["$date"] then
    settings["_api_key_verification_transition_start_at"] = settings["api_key_verification_transition_start_at"]["$date"]
  end
  settings["api_key_verification_transition_start_at"] = nil

  if settings["require_https_transition_start_at"] and settings["require_https_transition_start_at"]["$date"] then
    settings["_require_https_transition_start_at"] = settings["require_https_transition_start_at"]["$date"]
  end
  settings["require_https_transition_start_at"] = nil

  if settings["rate_limits"] then
    for _, limit in ipairs(settings["rate_limits"]) do
      local num_buckets = math.ceil(limit["duration"] / limit["accuracy"])

      -- For each bucket in this limit, store the time difference we'll
      -- subtract from the current time when determining each bucket's time.
      -- Sort the items so that the most recent bucket (0 time difference)
      -- comes last. This is to help minimize the amount of time between the
      -- metrics fetch for the current time bucket and the incrementing of that
      -- same bucket (see rate_limit.lua).
      limit["_bucket_time_diffs"] = {}
      for i = num_buckets - 1, 0, -1 do
        table.insert(limit["_bucket_time_diffs"], i * limit["accuracy"])
      end
    end
  end
end

function _M.parse_accept(header, supported_media_types)
  if not header then
    return nil
  end

  local accepts = {}
  local accept_header = split(header, ",", true)
  for index, accept_string in ipairs(accept_header) do
    local parts = split(accept_string, ";", true, 2)
    local media = parts[1]
    local params = parts[2]
    if params then
      params = split(params, ";", true)
    end

    local media_parts = split(media, "/", true)
    local media_type = strip(media_parts[1] or "")
    local media_subtype = strip(media_parts[2] or "")

    local q = 1
    if params then
      for _, param in ipairs(params) do
        local param_parts = split(param, "=", true)
        local param_key = strip(param_parts[1] or "")
        local param_value = strip(param_parts[2] or "")
        if param_key == "q" then
          q = tonumber(param_value) or 0
        end
      end
    end

    if q == 0 then
      break
    end

    local accept = {
      media_type = media_type,
      media_subtype = media_subtype,
      q = q,
      original_index = index,
    }

    table.insert(accepts, accept)
  end

  if accepts then
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
        return a.original_index < b.original_index
      end
    end)
  end

  for _, accept in ipairs(accepts) do
    for _, supported in ipairs(supported_media_types) do
      if accept.media_type == supported.media_type and accept.media_subtype == supported.media_subtype then
        return supported
      elseif accept.media_type == supported.media_type and accept.media_subtype == "*" then
        return supported
      elseif accept.media_type == "*" and accept.media_subtype == "*" then
        return supported
      end
    end
  end

  return nil
end

function _M.remove_arg(original_args, remove)
  local args = original_args
  if args then
    -- Remove the given argument name from the query string via a regex.
    --
    -- Note: OpenResty's table based approach with
    -- ngx.req.get_uri_args/ngx.req.set_uri_args would be a little cleaner, but
    -- ngx.req.get_uri_args re-sorts all the query parameters alphabetically,
    -- which we don't want to do by default. We could revisit this, but my
    -- thinking is that re-sorting the query parameters may interfere with some
    -- specific use-cases, like if the underlying API cares about the arg
    -- order, or if you were signing a URL with HMAC, in which case the order
    -- matters (although, in that case, stripping any arguments may also
    -- matter, but in general it just seems safer to default to doing less
    -- changes to the query string).
    local _, gsub_err
    args, _, gsub_err = gsub(args, "(?<=^|&)" .. remove .. "(?:=[^&]*)?(?:&|$)", "", "jo")
    if gsub_err then
      ngx.log(ngx.ERR, "regex error: ", gsub_err)
    end

    args, _, gsub_err = gsub(args, "&$", "")
    if gsub_err then
      ngx.log(ngx.ERR, "regex error: ", gsub_err)
    end
  end

  return args
end

function _M.append_args(original_args, append)
  local args = original_args
  if append then
    if args then
      args = args .. "&"
    end
    args = (args or "") .. append
  end

  return args
end

function _M.set_uri(new_path, new_args)
  local ngx_ctx = ngx.ctx
  local ngx_var = ngx.var

  if new_path then
    ngx.req.set_uri(new_path)

    -- Update the cached variable.
    ngx_ctx.uri = ngx_var.uri
  end

  if new_args then
    ngx.req.set_uri_args(new_args)

    -- Update the cached variable.
    ngx_ctx.args = ngx_var.args
  end

  -- If either value changed, update the cached request_uri variable. We have
  -- to manually put this together based on the other values since
  -- ngx.var.request_uri does not automatically update.
  if new_path or new_args then
    if ngx_ctx.args then
      ngx_ctx.request_uri = ngx_ctx.uri .. "?" .. ngx_ctx.args
    else
      ngx_ctx.request_uri = ngx_ctx.uri
    end
  end
end

function _M.round(value)
  return math.floor(value + 0.5)
end

return _M
