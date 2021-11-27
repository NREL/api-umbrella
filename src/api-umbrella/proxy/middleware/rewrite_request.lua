local config = require "api-umbrella.proxy.models.file_config"
local lustache = require "lustache"
local plutils = require "pl.utils"
local re_split = require("ngx.re").split
local tablex = require "pl.tablex"
local utils = require "api-umbrella.proxy.utils"
local xpcall_error_handler = require "api-umbrella.utils.xpcall_error_handler"

local gsub = ngx.re.gsub
local re_find = ngx.re.find
local re_match = ngx.re.match
local keys = tablex.keys
local set_uri = utils.set_uri
local size = tablex.size
local split = plutils.split

local function pass_api_key(settings)
  local api_key = ngx.ctx.api_key

  -- DEPRECATED: We don't want to pass api keys to backends for security
  -- reasons. Instead, we want to only pass the X-Api-User-Id for identifying
  -- the user. But for legacy purposes, we still support passing api keys to
  -- specific backends.
  local pass_api_key_header = settings["pass_api_key_header"]
  if pass_api_key_header and api_key then
    -- Standardize how the api key is passed to backends, so backends only have
    -- to check one place (the HTTP header).
    ngx.req.set_header("X-Api-Key", api_key)
  else
    ngx.req.clear_header("X-Api-Key")
  end

  -- DEPRECATED: We don't want to pass api keys to backends (see above).
  -- Passing it via the query string is even worse, since it prevents
  -- caching, but again, for legacy purposes, we support passing it this way
  -- for specific backends.
  local pass_api_key_query_param = settings["pass_api_key_query_param"]
  local arg_api_key = ngx.ctx.arg_api_key
  if pass_api_key_query_param and api_key then
    if arg_api_key ~= api_key then
      local args = utils.remove_arg(ngx.ctx.args, "api_key")
      args = utils.append_args(args, "api_key=" .. api_key)
      set_uri(nil, args)
    end
  else
    -- Strip the api key from the query string, so better HTTP caching can be
    -- performed (so the URL won't vary for each user).
    local args = utils.remove_arg(ngx.ctx.args, "api_key")
    set_uri(nil, args)
  end

  -- Never pass along basic auth if it's how the api key was passed in
  -- (otherwise, we don't want to touch the basic auth and pass along
  -- whatever it contains)..
  if api_key and ngx.ctx.remote_user == api_key then
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
    ngx.req.set_header("X-Api-Roles", table.concat(keys(user["roles"]), ","))
  else
    ngx.req.clear_header("X-Api-Roles")
  end
end

local function append_query_string(settings)
  if settings["append_query_string"] then
    local args = ngx.ctx.args

    -- First remove any existing query parameters that match the names of the
    -- query parameters we're going to override.
    if settings["_append_query_arg_names"] then
      for _, arg_name in ipairs(settings["_append_query_arg_names"]) do
        args = utils.remove_arg(args, arg_name)
      end
    end

    -- Next, add the query string to the end.
    args = utils.append_args(args, settings["append_query_string"])
    set_uri(nil, args)
  end
end

local function set_headers(settings)
  local template_vars = nil

  if settings["_headers"] then
    for _, header in ipairs(settings["_headers"]) do
      local value = nil

      -- The headers replacement may optionally be processed as a Mustache
      -- template, but for efficiency only do that if we've detected the value
      -- is a template.
      if header["_process_as_template"] then
        -- Only generate the mustache template variables if a mustache template
        -- header is being used. But then cache it for potential subsequent
        -- headers in this loop.
        if not template_vars then
          template_vars = {
            headers = ngx.req.get_headers(),
          }

          setmetatable(template_vars["headers"], nil)
        end

        local ok, output = xpcall(lustache.render, xpcall_error_handler, lustache, header["value"], template_vars)
        if ok then
          value = output
        else
          ngx.log(ngx.ERR, "Mustache rendering error while rendering error template: " .. (tostring(output) or ""))
        end
      else
        value = header["value"]
      end

      ngx.req.set_header(header["key"], value)
    end
  end
end

local function set_http_basic_auth(settings)
  if settings["_http_basic_auth_header"] then
    ngx.req.clear_header("Authorization")
    ngx.req.set_header("X-Api-Umbrella-Backend-Authorization", settings["_http_basic_auth_header"])
  end
end

local function strip_cookies(api)
  local cookie_header = ngx.var.http_cookie
  if not cookie_header then
    return
  end

  local strip_request_cookie_regex
  if api["id"] == "api-umbrella-web-app-backend" then
    strip_request_cookie_regex = config["_strip_request_cookies_regex_web_app_backend"]
  else
    strip_request_cookie_regex = config["_strip_request_cookies_regex_non_web_app_backends"]
  end

  if not strip_request_cookie_regex then
    return
  end

  local cookies, split_err = re_split(cookie_header, "; *", "jo")
  if split_err then
    ngx.log(ngx.ERR, "regex error: ", split_err)
    return
  end

  local kept_cookies = {}
  for _, cookie in ipairs(cookies) do
    local cookie_name = string.match(cookie, "(.-)=")

    local find_from, _, find_err = re_find(cookie_name, strip_request_cookie_regex, "ijo")
    if find_err then
      ngx.log(ngx.ERR, "regex error: ", find_err)
    end

    if not find_from then
      table.insert(kept_cookies, cookie)
    end
  end

  if #kept_cookies == 0 then
    ngx.req.clear_header("Cookie")
  else
    ngx.req.set_header("Cookie", table.concat(kept_cookies, "; "))
  end
end

local function url_rewrites(api)
  if not api["rewrites"] then return end

  local request_method = ngx.ctx.request_method
  local original_uri = ngx.ctx.request_uri
  local new_uri = ngx.ctx.request_uri

  for _, rewrite in ipairs(api["rewrites"]) do
    if rewrite["http_method"] == "any" or rewrite["http_method"] == request_method then
      if rewrite["matcher_type"] == "regex" and rewrite["frontend_matcher"] and rewrite["backend_replacement"] then
        local _, gsub_err
        new_uri, _, gsub_err = gsub(new_uri, rewrite["frontend_matcher"], rewrite["backend_replacement"], "io")
        if gsub_err then
          ngx.log(ngx.ERR, "regex error: ", gsub_err)
        end

      -- Route pattern matching implementation based on
      -- https://github.com/bjoerge/route-pattern
      -- TODO: Cleanup!
      elseif rewrite["matcher_type"] == "route" and rewrite["_frontend_path_regex"] then
        local parts = split(new_uri, "?", true, 2)
        local path = parts[1]
        local args = parts[2]
        local args_length = 0
        if args then
          args = ngx.decode_args(args)
          args_length = size(args)
        end

        local matches, match_err = re_match(path, rewrite["_frontend_path_regex"])
        if matches then
          if rewrite["_frontend_args_length"] then
            if rewrite["_frontend_args_allow_wildcards"] or args_length == rewrite["_frontend_args_length"] then
              for key, value in pairs(rewrite["_frontend_args"]) do
                if value["must_equal"] and args[key] ~= value["must_equal"] then
                  matches = false
                elseif value["named_capture"] then
                  matches[value["named_capture"]] = args[key]
                end
              end
            else
              matches = false
            end
          end

          if matches then
            for key, value in pairs(matches) do
              if type(value) == "table" then
                matches[key] = table.concat(value, ",")
              end
            end

            local ok, output = xpcall(lustache.render, xpcall_error_handler, lustache, rewrite["_backend_replacement_path"], matches)
            if ok then
              new_uri = output
            else
              ngx.log(ngx.ERR, "Mustache rendering error while rendering error template: " .. (tostring(output) or ""))
            end

            if rewrite["_backend_replacement_args"] then
              for key, value in pairs(matches) do
                matches[key] = ngx.escape_uri(value)
              end

              ok, output = xpcall(lustache.render, xpcall_error_handler, lustache, rewrite["_backend_replacement_args"], matches)
              if ok then
                new_uri = new_uri .. "?" .. output
              else
                ngx.log(ngx.ERR, "Mustache rendering error while rendering error template: " .. (tostring(output) or ""))
              end
            end
          end
        elseif match_err then
          ngx.log(ngx.ERR, "regex error: ", match_err)
        end
      end
    end
  end

  if new_uri ~= original_uri then
    local parts = split(new_uri, "?", true, 2)
    local path = parts[1]
    local args = parts[2] or {}
    set_uri(path, args)
  end
end

return function(user, api, settings)
  pass_api_key(settings)
  set_user_id_header(user)
  set_roles_header(user)
  append_query_string(settings)
  set_headers(settings)
  set_http_basic_auth(settings)
  strip_cookies(api)
  url_rewrites(api)
end
