local moses = require "moses"
local inspect = require "inspect"
local utils = require "utils"
local std_string = require "std.string"
local stringx = require "pl.stringx"

local pass_api_key = function(user, settings)
  -- DEPRECATED: We don't want to pass api keys to backends for security
  -- reasons. Instead, we want to only pass the X-Api-User-Id for identifying
  -- the user. But for legacy purposes, we still support passing api keys to
  -- specific backends.
  local pass_api_key_header = settings["pass_api_key_header"]
  if pass_api_key_header and user then
    -- Standardize how the api key is passed to backends, so backends only have
    -- to check one place (the HTTP header).
    ngx.req.set_header("X-Api-Key", user["api_key"])
  else
    ngx.req.clear_header("X-Api-Key")
  end

  -- DEPRECATED: We don't want to pass api keys to backends (see above).
  -- Passing it via the query string is even worse, since it prevents
  -- caching, but again, for legacy purposes, we support passing it this way
  -- for specific backends.
  local pass_api_key_query_param = settings["pass_api_key_query_param"]
  local arg_api_key = ngx.var.arg_api_key
  if pass_api_key_query_param and user then
    if arg_api_key ~= user["api_key"] then
      local args = ngx.req.get_uri_args() or {}
      args["api_key"] = user["api_key"]
      ngx.req.set_uri_args(args)
    end
  elseif arg_api_key then
    -- Strip the api key from the query string, so better HTTP caching can be
    -- performed (so the URL won't vary for each user).
    local args = ngx.req.get_uri_args() or {}
    args["api_key"] = nil
    ngx.req.set_uri_args(args)
  end

  -- Never pass along basic auth if it's how the api key was passed in
  -- (otherwise, we don't want to touch the basic auth and pass along
  -- whatever it contains)..
  if user and ngx.var.remote_user == user["api_key"] then
    ngx.req.clear_header("Authorization")
  end
end

local set_user_id_header = function(user)
  if user then
    ngx.req.set_header("X-Api-User-Id", user["id"])
  else
    ngx.req.clear_header("X-Api-User-Id")
  end
end

local set_roles_header = function(user)
  if user and user["roles"] then
    ngx.req.set_header("X-Api-Roles", moses.concat(user["roles"], ","))
  else
    ngx.req.clear_header("X-Api-Roles")
  end
end

local append_query_string = function(settings)
  if settings["append_query_string"] then
    local args = ngx.req.get_uri_args() or {}
    local append_args = ngx.decode_args(settings["append_query_string"])
    utils.deep_merge_overwrite_arrays(args, append_args)
    ngx.req.set_uri_args(args)
  end
end

local set_headers = function(settings)
  if settings["headers"] then
    for _, header in ipairs(settings["headers"]) do
      ngx.req.set_header(header["key"], header["value"])
    end
  end
end

local set_http_basic_auth = function(settings)
  if settings["http_basic_auth"] then
    local auth = "Basic " .. ngx.encode_base64(settings["http_basic_auth"])
    ngx.req.set_header("Authorization", auth)
  end
end

local strip_cookies = function(settings)
  local cookie_header = ngx.var.http_cookie
  local strips = config["strip_cookies"]
  if cookie_header and strips then
    local cookies = std_string.split(cookie_header, "; *")
    local kept_cookies = {}

    for _, cookie in ipairs(cookies) do
      local cookie_name = string.match(cookie, "(.-)=")
      local remove_cookie = false

      if cookie_name then
        cookie_name = stringx.strip(cookie_name)
        for _, strip_regex in ipairs(strips) do
          local matches, err = ngx.re.match(cookie_name, strip_regex, "i")
          if matches then
            remove_cookie = true
            break
          end
        end
      end

      if not remove_cookie then
        table.insert(kept_cookies, cookie)
      end
    end

    if moses.isEmpty(kept_cookies) then
      ngx.req.clear_header("Cookie")
    else
      ngx.req.set_header("Cookie", moses.concat(kept_cookies, "; "))
    end
  end
end

return function(user, api, settings)
  pass_api_key(user, settings)
  set_user_id_header(user)
  set_roles_header(user)
  append_query_string(settings)
  set_headers(settings)
  set_http_basic_auth(settings)
  strip_cookies(settings)
end
