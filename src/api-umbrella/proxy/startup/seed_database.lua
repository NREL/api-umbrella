local deep_merge_overwrite_arrays = require "api-umbrella.utils.deep_merge_overwrite_arrays"
local interval_lock = require "api-umbrella.utils.interval_lock"
local pg_utils = require "api-umbrella.utils.pg_utils"
local random_token = require "api-umbrella.utils.random_token"
local uuid = require "resty.uuid"

local function wait_for_postgres()
  local postgres_alive = false
  local wait_time = 0
  local sleep_time = 0.5
  local max_time = 14
  repeat
    local ok, err = pg_utils.connect()
    if not ok then
      ngx.log(ngx.NOTICE, "failed to establish connection to postgres (this is expected if postgres is starting up at the same time): ", err)
    else
      postgres_alive = true
    end

    if not postgres_alive then
      ngx.sleep(sleep_time)
      wait_time = wait_time + sleep_time
    end
  until postgres_alive or wait_time > max_time

  if postgres_alive then
    return true, nil
  else
    return false, "postgres was not ready within " .. max_time  .."s"
  end
end

local function seed_api_keys()
  local keys = {
    -- static.site.ajax@internal.apiumbrella
    {
      api_key = config["static_site"]["api_key"],
      email = "static.site.ajax@internal.apiumbrella",
      first_name = "API Umbrella Static Site",
      last_name = "Key",
      use_description = "An API key for the API Umbrella static website to use for ajax requests.",
      registration_source = "seed",
      roles = { "api-umbrella-key-creator", "api-umbrella-contact-form" },
      settings = {
        rate_limit_mode = "custom",
        rate_limits = {
          {
            duration = 1 * 60 * 1000, -- 1 minute
            accuracy = 5 * 1000, -- 5 seconds
            limit_by = "ip",
            limit = 5,
            response_headers = false,
          },
          {
            duration = 60 * 60 * 1000, -- 1 hour
            accuracy = 1 * 60 * 1000, -- 1 minute
            limit_by = "ip",
            limit = 20,
            response_headers = true,
          },
        },
      },
    },

    -- web.admin.ajax@internal.apiumbrella
    {
      email = "web.admin.ajax@internal.apiumbrella",
      first_name = "API Umbrella Admin",
      last_name = "Key",
      use_description = "An API key for the API Umbrella admin to use for internal ajax requests.",
      registration_source = "seed",
      roles = { "api-umbrella-key-creator" },
      settings = {
        rate_limit_mode = "unlimited",
      },
    },
  }

  for _, data in ipairs(keys) do
    local result, user_err = pg_utils.query("SELECT * FROM api_users WHERE email = $1 ORDER BY created_at LIMIT 1", data["email"])
    if not result then
      ngx.log(ngx.ERR, "failed to query api_users: ", user_err)
      break
    end

    local user = result[1]
    if user then
      deep_merge_overwrite_arrays(user, data)
    else
      user = data
    end

    if not user["id"] then
      user["id"] = uuid.generate_random()
    end
    if not user["api_key"] then
      user["api_key"] = random_token(40)
    end
    if user["roles"] then
      user["roles"] = pg_utils.as_array(user["roles"])
    end
    if user["settings"] then
      if not user["settings"]["id"] then
        user["settings"]["id"] = uuid.generate_random()
      end

      if user["settings"]["rate_limits"] then
        for _, rate_limit in ipairs(user["settings"]["rate_limits"]) do
          if not rate_limit["id"] then
            rate_limit["id"] = uuid.generate_random()
          end
        end
      end

      user["settings"] = pg_utils.as_json(user["settings"])
    end

    if result[1] then
      local update_result, update_err = pg_utils.update("api_users", { id = user["id"] }, user)
      if not update_result then
        ngx.log(ngx.ERR, "failed to update record in api_users: ", update_err)
      end
    else
      local insert_result, insert_err = pg_utils.insert("api_users", user)
      if not insert_result then
        ngx.log(ngx.ERR, "failed to create record in api_users: ", insert_err)
      end
    end
  end
end

local function seed_initial_superusers()
  for _, username in ipairs(config["web"]["admin"]["initial_superusers"]) do
    local result, admin_err = pg_utils.query("SELECT * FROM admins WHERE username = $1 LIMIT 1", username)
    if not result then
      ngx.log(ngx.ERR, "failed to query admins: ", admin_err)
      break
    end

    local data = {
      username = username,
      superuser = true,
      registration_source = "seed",
    }

    local admin = result[1]
    if admin then
      deep_merge_overwrite_arrays(admin, data)
    else
      admin = data
    end

    if not admin["id"] then
      admin["id"] = uuid.generate_random()
    end
    if not admin["authentication_token"] then
      admin["authentication_token"] = random_token(40)
    end

    if result[1] then
      local update_result, update_err = pg_utils.update("admins", { id = admin["id"] }, admin)
      if not update_result then
        ngx.log(ngx.ERR, "failed to update record in admins: ", update_err)
      end
    else
      local insert_result, insert_err = pg_utils.insert("admins", admin)
      if not insert_result then
        ngx.log(ngx.ERR, "failed to create record in admins: ", insert_err)
      end
    end
  end
end

local function seed_admin_permissions()
  local permissions = {
    {
      id = "analytics",
      name = "Analytics",
      display_order = 1,
    },
    {
      id = "user_view",
      name = "API Users - View",
      display_order = 2,
    },
    {
      id = "user_manage",
      name = "API Users - Manage",
      display_order = 3,
    },
    {
      id = "admin_manage",
      name = "Admin Accounts - View & Manage",
      display_order = 4,
    },
    {
      id = "backend_manage",
      name = "API Backend Configuration - View & Manage",
      display_order = 5,
    },
    {
      id = "backend_publish",
      name = "API Backend Configuration - Publish",
      display_order = 6,
    },
  }

  for _, data in ipairs(permissions) do
    local result, permission_err = pg_utils.query("SELECT * FROM admin_permissions WHERE id = $1 LIMIT 1", data["id"])
    if not result then
      ngx.log(ngx.ERR, "failed to query admin_permissions: ", permission_err)
      break
    end

    local permission = result[1]
    if permission then
      deep_merge_overwrite_arrays(permission, data)
    else
      permission = data
    end

    if result[1] then
      local update_result, update_err = pg_utils.update("admin_permissions", { id = permission["id"] }, permission)
      if not update_result then
        ngx.log(ngx.ERR, "failed to update record in admin_permissions: ", update_err)
      end
    else
      local insert_result, insert_err = pg_utils.insert("admin_permissions", permission)
      if not insert_result then
        ngx.log(ngx.ERR, "failed to create record in admin_permissions: ", insert_err)
      end
    end
  end
end

local function seed()
  local _, err = wait_for_postgres()
  if err then
    ngx.log(ngx.ERR, "timed out waiting for postgres before seeding, rerunning...")
    ngx.sleep(5)
    return seed()
  end

  pg_utils.query("SET application.name = 'proxy'")
  pg_utils.query("SET application.\"user\" = 'proxy'")

  seed_api_keys()
  seed_initial_superusers()
  seed_admin_permissions()
end

local function seed_once()
  interval_lock.mutex_exec("seed_database", seed)
end

return function()
  local ok, err = ngx.timer.at(0, seed_once)
  if not ok then
    ngx.log(ngx.ERR, "failed to create timer: ", err)
    return
  end
end
