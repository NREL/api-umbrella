local api_key_validator = require "api_key_validator"
local api_matcher = require "api_matcher"
local api_settings = require "api_settings"
local error_handler = require "error_handler"
local rate_limit = require "rate_limit"
local rewrite_request = require "rewrite_request"
local role_validator = require "role_validator"
local user_settings = require "user_settings"

local inspect = require "inspect"

local api, url_match, err = api_matcher()
if err then
  return error_handler(err)
end

local settings, err = api_settings(api)
if err then
  return error_handler(err)
end

local user, err = api_key_validator(settings)
if err then
  return error_handler(err)
end

local err = user_settings(settings, user)
if err then
  return error_handler(err)
end

local err = role_validator(settings, user)
if err then
  return error_handler(err)
end

local err = rate_limit(settings, user)
if err then
  return error_handler(err)
end

local err = rewrite_request(user, api, settings)
if err then
  return error_handler(err)
end
