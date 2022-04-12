local _M = {}

local gsub = ngx.re.gsub

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

function _M.append_args(original_args, append, question_prefix)
  local args = original_args
  if append then
    if args then
      args = args .. "&"
    elseif question_prefix then
      args = "?"
    else
      args = ""
    end

    args = args .. append
  end

  return args
end

function _M.set_uri(new_path, new_args)
  local ngx_ctx = ngx.ctx

  if new_path then
    ngx.req.set_uri(new_path)

    -- Update the cached variable.
    ngx_ctx.uri_path = ngx.var.uri
  end

  if new_args then
    ngx.req.set_uri_args(new_args)

    -- Update the cached variable.
    ngx_ctx.args = ngx.var.args
  end

  -- If either value changed, update the cached request_uri variable. We have
  -- to manually put this together based on the other values since
  -- ngx.var.request_uri does not automatically update.
  if new_path or new_args then
    if ngx_ctx.args then
      ngx_ctx.request_uri = ngx_ctx.uri_path .. "?" .. ngx_ctx.args
    else
      ngx_ctx.request_uri = ngx_ctx.uri_path
    end
  end
end

return _M
