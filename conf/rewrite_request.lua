local inspect = require "inspect"
local plutils = require "pl.utils"
local stringx = require "pl.stringx"
local types = require "pl.types"
local utils = require "utils"

local deep_merge_overwrite_arrays = utils.deep_merge_overwrite_arrays
local is_empty = types.is_empty
local split = plutils.split
local strip = stringx.strip

local function pass_api_key(user, settings)
  ngx.req.set_header("X-Api-Umbrella-Backend-Id", ngx.var.api_umbrella_backend_id)

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
  local arg_api_key = ngx.ctx.arg_api_key
  if pass_api_key_query_param and arg_api_key and user then
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
  if user and ngx.ctx.remote_user == user["api_key"] then
    ngx.req.clear_header("Authorization")
  end
end

local function set_user_id_header(user)
  if user then
    ngx.req.set_header("X-Api-User-Id", user["id"])
  else
    ngx.req.clear_header("X-Api-User-Id")
  end
end

local function set_roles_header(user)
  if user and user["roles"] then
    ngx.req.set_header("X-Api-Roles", table.concat(user["roles"], ","))
  else
    ngx.req.clear_header("X-Api-Roles")
  end
end

local function append_query_string(settings)
  if settings["_append_query_args"] then
    local args = ngx.req.get_uri_args() or {}
    deep_merge_overwrite_arrays(args, settings["_append_query_args"])
    ngx.req.set_uri_args(args)
  end
end

local function set_headers(settings)
  if settings["headers"] then
    for _, header in ipairs(settings["headers"]) do
      ngx.req.set_header(header["key"], header["value"])
    end
  end
end

local function set_http_basic_auth(settings)
  if settings["_http_basic_auth_header"] then
    ngx.req.set_header("Authorization", settings["_http_basic_auth_header"])
  end
end

local function strip_cookies(settings)
  local cookie_header = ngx.var.http_cookie
  if not cookie_header then return end

  local strips = config["strip_cookies"]
  if not strips then return end

  local cookies = split(cookie_header, "; *")
  local kept_cookies = {}

  for _, cookie in ipairs(cookies) do
    local cookie_name = string.match(cookie, "(.-)=")
    local remove_cookie = false

    if cookie_name then
      cookie_name = strip(cookie_name)
      for _, strip_regex in ipairs(strips) do
        local matches, err = ngx.re.match(cookie_name, strip_regex, "io")
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

  if is_empty(kept_cookies) then
    ngx.req.clear_header("Cookie")
  else
    ngx.req.set_header("Cookie", table.concat(kept_cookies, "; "))
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
