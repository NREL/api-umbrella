local lock = require "resty.lock"
local mongo = require "api-umbrella.utils.mongo"
local random_token = require "api-umbrella.utils.random_token"
local uuid = require "resty.uuid"

local function seed_static_site_api_key()
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
      created_at = { ["$date"] = { ["$numberLong"] = tostring(os.time() * 1000) } },
      updated_at = { ["$date"] = { ["$numberLong"] = tostring(os.time() * 1000) } },
    })

    if create_err then
      ngx.log(ngx.ERR, "failed to create api user: ", create_err)
      return
    end
  end
end

local function seed_web_admin_api_key()
  local user, user_err = mongo.first("api_users", {
    query = {
      email = "web.admin.ajax@internal.apiumbrella",
    },
  })

  if user_err then
    ngx.log(ngx.ERR, "failed to query api_users: ", user_err)
    return
  end

  if not user then
    local _, create_err = mongo.create("api_users", {
      _id = uuid.generate_random(),
      api_key = random_token(40),
      email = "web.admin.ajax@internal.apiumbrella",
      first_name = "API Umbrella Admin",
      last_name = "Key",
      use_description = "An API key for the API Umbrella admin to use for internal ajax requests.",
      terms_and_conditions = "1",
      registration_source = "seed",
      settings = {
        _id = uuid.generate_random(),
        rate_limit_mode = "unlimited",
      },
      created_at = { ["$date"] = { ["$numberLong"] = tostring(os.time() * 1000) } },
      updated_at = { ["$date"] = { ["$numberLong"] = tostring(os.time() * 1000) } },
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
        created_at = { ["$date"] = { ["$numberLong"] = tostring(os.time() * 1000) } },
        updated_at = { ["$date"] = { ["$numberLong"] = tostring(os.time() * 1000) } },
      })

      if create_err then
        ngx.log(ngx.ERR, "failed to create admin: ", create_err)
        break
      end
    elseif admin and not admin["superuser"] then
      admin["superuser"] = true
      admin["updated_at"] = { ["$date"] = { ["$numberLong"] = tostring(os.time() * 1000) } }
      local _, update_err = mongo.update("admins", admin["_id"], admin)

      if update_err then
        ngx.log(ngx.ERR, "failed to update admin: ", update_err)
        break
      end
    end
  end
end

local function seed_admin_permissions()
  local permissions = {
    {
      _id = "analytics",
      name = "Analytics",
      display_order = 1,
    },
    {
      _id = "user_view",
      name = "API Users - View",
      display_order = 2,
    },
    {
      _id = "user_manage",
      name = "API Users - Manage",
      display_order = 3,
    },
    {
      _id = "admin_manage",
      name = "Admin Accounts - View & Manage",
      display_order = 4,
    },
    {
      _id = "backend_manage",
      name = "API Backend Configuration - View & Manage",
      display_order = 5,
    },
    {
      _id = "backend_publish",
      name = "API Backend Configuration - Publish",
      display_order = 6,
    },
  }

  for _, data in ipairs(permissions) do
    local permission, permission_err = mongo.first("admin_permissions", {
      query = {
        _id = data["_id"],
      },
    })

    if permission_err then
      ngx.log(ngx.ERR, "failed to query admin_permissions: ", permission_err)
      break
    end

    if not permission then
      data["created_at"] = { ["$date"] = { ["$numberLong"] = tostring(os.time() * 1000) } }
      data["updated_at"] = { ["$date"] = { ["$numberLong"] = tostring(os.time() * 1000) } }
      local _, create_err = mongo.create("admin_permissions", data)

      if create_err then
        ngx.log(ngx.ERR, "failed to create admin_permission: ", create_err)
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

  seed_static_site_api_key()
  seed_web_admin_api_key()
  seed_initial_superusers()
  seed_admin_permissions()
end

return function()
  local ok, err = ngx.timer.at(0, seed)
  if not ok then
    ngx.log(ngx.ERR, "failed to create timer: ", err)
    return
  end
end
