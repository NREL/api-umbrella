local deep_merge_overwrite_arrays = require "api-umbrella.utils.deep_merge_overwrite_arrays"
local interval_lock = require "api-umbrella.utils.interval_lock"
local mongo = require "api-umbrella.utils.mongo"
local random_token = require "api-umbrella.utils.random_token"
local uuid = require "resty.uuid"

local nowMongoDate = { ["$date"] = { ["$numberLong"] = tostring(os.time() * 1000) } }

local function wait_for_mongodb()
  local mongodb_alive = false
  local wait_time = 0
  local sleep_time = 0.5
  local max_time = 14
  repeat
    local _, err = mongo.collections()
    if err then
      ngx.log(ngx.NOTICE, "failed to establish connection to mongodb (this is expected if mongodb is starting up at the same time): ", err)
    else
      mongodb_alive = true
    end

    if not mongodb_alive then
      ngx.sleep(sleep_time)
      wait_time = wait_time + sleep_time
    end
  until mongodb_alive or wait_time > max_time

  if mongodb_alive then
    return true, nil
  else
    return false, "elasticsearch was not ready within " .. max_time  .."s"
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
    },

    -- web.admin.ajax@internal.apiumbrella
    {
      email = "web.admin.ajax@internal.apiumbrella",
      first_name = "API Umbrella Admin",
      last_name = "Key",
      use_description = "An API key for the API Umbrella admin to use for internal ajax requests.",
      terms_and_conditions = "1",
      registration_source = "seed",
      roles = { "api-umbrella-key-creator" },
      settings = {
        _id = uuid.generate_random(),
        rate_limit_mode = "unlimited",
      },
    },
  }

  for _, data in ipairs(keys) do
    local user, user_err = mongo.first("api_users", {
      query = {
        email = data["email"],
      },
      sort = "created_at",
    })

    if user_err then
      ngx.log(ngx.ERR, "failed to query api_users: ", user_err)
      break
    end

    if user then
      deep_merge_overwrite_arrays(user, data)
      if not user["api_key"] then
        user["api_key"] = random_token(40)
      end
      user["updated_at"] = nowMongoDate

      local _, update_err = mongo.update("api_users", user["_id"], user)
      if update_err then
        ngx.log(ngx.ERR, "failed to update record in api_users: ", update_err)
      end
    else
      data["_id"] = uuid.generate_random()
      if not data["api_key"] then
        data["api_key"] = random_token(40)
      end
      data["created_at"] = nowMongoDate
      data["updated_at"] = nowMongoDate

      local _, create_err = mongo.create("api_users", data)
      if create_err then
        ngx.log(ngx.ERR, "failed to create record in api_users: ", create_err)
      end
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

    local data = {
      username = username,
      superuser = true,
      registration_source = "seed",
    }

    if admin then
      deep_merge_overwrite_arrays(admin, data)
      if not admin["authentication_token"] then
        admin["authentication_token"] = random_token(40)
      end
      admin["updated_at"] = nowMongoDate

      local _, update_err = mongo.update("admins", admin["_id"], admin)
      if update_err then
        ngx.log(ngx.ERR, "failed to update record in admins: ", update_err)
      end
    else
      data["_id"] = uuid.generate_random()
      data["authentication_token"] = random_token(40)
      data["created_at"] = nowMongoDate
      data["updated_at"] = nowMongoDate

      local _, create_err = mongo.create("admins", data)
      if create_err then
        ngx.log(ngx.ERR, "failed to create record in admins: ", create_err)
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
        ["_id"] = data["_id"],
      },
    })

    if permission_err then
      ngx.log(ngx.ERR, "failed to query admin_permissions: ", permission_err)
      break
    end

    if permission then
      deep_merge_overwrite_arrays(permission, data)
      permission["updated_at"] = nowMongoDate

      local _, update_err = mongo.update("admin_permissions", permission["_id"], permission)
      if update_err then
        ngx.log(ngx.ERR, "failed to update record in admin_permissions: ", update_err)
      end
    else
      data["created_at"] = nowMongoDate
      data["updated_at"] = nowMongoDate

      local _, create_err = mongo.create("admin_permissions", data)
      if create_err then
        ngx.log(ngx.ERR, "failed to create record in admin_permissions: ", create_err)
      end
    end
  end
end

local function seed()
  local _, err = wait_for_mongodb()
  if not err then
    seed_api_keys()
    seed_initial_superusers()
    seed_admin_permissions()
  else
    ngx.log(ngx.ERR, "timed out waiting for mongodb before seeding, rerunning...")
    ngx.sleep(5)
    seed()
  end
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
