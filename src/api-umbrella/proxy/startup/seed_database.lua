local lock = require "resty.lock"
local mongo = require "api-umbrella.utils.mongo"
local random_token = require "api-umbrella.utils.random_token"
local uuid = require "resty.uuid"

local function seed_api_keys()
  local user, user_err = mongo.first("api_users", {
    query = {
      api_key = config["static_site"]["api_key"],
    },
  })

  if user_err then
    ngx.log(ngx.ERR, "failed to query api_users: ", user_err)
    return
  end

  if not user then
    local _, create_err = mongo.create("api_users", {
      _id = uuid.generate_random(),
      api_key = config["static_site"]["api_key"],
      email = "static.site.ajax@internal.apiumbrella",
      first_name = "API Umbrella Static Site",
      last_name = "Key",
      use_description = "An API key for the API Umbrella static website to use for ajax requests.",
      terms_and_conditions = "1",
      registration_source = "seed",
      roles = { "api-umbrella-key-creator", "api-umbrella-contact-form" },
      settings = {
        _id = uuid.generate_random(),
        rate_limit_mode = "custom",
        rate_limits = {
          {
            _id = uuid.generate_random(),
            duration = 1 * 60 * 1000, -- 1 minute
            accuracy = 5 * 1000, -- 5 seconds
            limit_by = "ip",
            limit = 5,
            response_headers = false,
          },
          {
            _id = uuid.generate_random(),
            duration = 60 * 60 * 1000, -- 1 hour
            accuracy = 1 * 60 * 1000, -- 1 minute
            limit_by = "ip",
            limit = 20,
            response_headers = true,
          },
        },
      },
    })

    if create_err then
      ngx.log(ngx.ERR, "failed to create api user: ", create_err)
      return
    end
  end
end

local function seed_initial_superusers()
  for _, username in ipairs(config["web"]["admin"]["initial_superusers"]) do
    local admin, admin_err = mongo.first("admins", {
      query = {
        username = username,
      },
    })

    if admin_err then
      ngx.log(ngx.ERR, "failed to query admins: ", admin_err)
      break
    end

    if not admin then
      local _, create_err = mongo.create("admins", {
        _id = uuid.generate_random(),
        username = username,
        superuser = true,
        authentication_token = random_token(40),
      })

      if create_err then
        ngx.log(ngx.ERR, "failed to create admin: ", create_err)
        break
      end
    elseif admin and not admin["superuser"] then
      admin["superuser"] = true
      local _, update_err = mongo.update("admins", admin["_id"], admin)

      if update_err then
        ngx.log(ngx.ERR, "failed to update admin: ", update_err)
        break
      end
    end
  end
end

local function seed()
  local seed_lock = lock:new("locks", { ["timeout"] = 0 })
  local _, lock_err = seed_lock:lock("seed_database")
  if lock_err then
    return
  end

  seed_api_keys()
  seed_initial_superusers()
end

return function()
  local ok, err = ngx.timer.at(0, seed)
  if not ok then
    ngx.log(ngx.ERR, "failed to create timer: ", err)
    return
  end
end
