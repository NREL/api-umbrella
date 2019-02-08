local argparse = require "argparse"
local encryptor = require "api-umbrella.utils.encryptor"
local hmac = require "api-umbrella.utils.hmac"
local icu_date = require "icu-date"
local inspect = require "inspect"
local is_empty = require("pl.types").is_empty
local mongo = require "mongo"
local pg_encode_array = require "api-umbrella.utils.pg_encode_array"
local pg_null = require("pgmoon").Postgres.NULL
local pg_utils = require "api-umbrella.utils.pg_utils"
local random_seed = require "api-umbrella.utils.random_seed"
local random_token = require "api-umbrella.utils.random_token"
local seed_database = require "api-umbrella.proxy.startup.seed_database"
local uuid_generate = require("resty.uuid").generate_random

local API_KEY_PREFIX_LENGTH = 16
local admin_usernames = {}
local args = {}
local date = icu_date.new()
local deletes = {}
local format_iso8601 = icu_date.formats.iso8601()
local mongo_client
local mongo_database

random_seed()

local function parse_args()
  local parser = argparse("api-umbrella", "Open source API management")

  parser:option("--mongodb-url", "Input MongoDB database URL."):count(1)
  parser:option("--postgresql", "Output Elasticsearch database URL."):count(1)
  parser:flag("--clean", "Clean")

  local parsed_args = parser:parse()
  return parsed_args
end

local function track_delete(table_name, id)
  if not deletes[table_name] then
    deletes[table_name] = {}
  end

  deletes[table_name][id] = true
end

local function admin_username(id)
  if not id or id == pg_null then
    return nil
  elseif admin_usernames[id] then
    return admin_usernames[id]
  else
    print("Could not find admin username for ID: " .. inspect(id))
    return nil
  end
end

local function nulls(table)
  if not table then return end

  for key, value in pairs(table) do
    if value == mongo.Null then
      table[key] = pg_null
    elseif type(value) == "string" then
      -- Strip null byte characters that aren't allowed in Postgres.
      table[key] = ngx.re.gsub(value, [[\0]], "", "jo")
    elseif type(value) == "table" then
      table[key] = nulls(value)
    end
  end

  return table
end

local function datetimes(table)
  if not table then return end

  for key, value in pairs(table) do
    if type(value) == "table" and value.__name == "mongo.DateTime" then
      date:set_millis(value:unpack())
      table[key] = date:format(format_iso8601)
    elseif type(value) == "table" then
      table[key] = datetimes(value)
    end
  end

  return table
end

local function query(...)
  local result, err = pg_utils.query(...)
  if err then
    print("failed to perform postgresql query: " .. err)
    os.exit(1)
  end

  return result, err
end

local function delete(table_name, where)
  local result, err = pg_utils.delete(table_name, where)
  if err then
    print("failed to perform postgresql delete: " .. err)
    os.exit(1)
  end

  return result, err
end

local function insert(table_name, row, after_insert)
  nulls(row)
  datetimes(row)

  if row["_id"] then
    row["id"] = row["_id"]
    row["_id"] = nil
  end

  if row["created_by"] then
    row["created_by_id"] = row["created_by"]
    row["created_by_username"] = admin_username(row["created_by"])
    row["created_by"] = nil
  end
  if not row["created_by_id"] or row["created_by_id"] == pg_null then
    row["created_by_id"] = "00000000-0000-0000-0000-000000000000"
  end
  if not row["created_by_username"] or row["created_by_username"] == pg_null then
    row["created_by_username"] = "Unknown (Imported)"
  end

  if row["updated_by"] then
    row["updated_by_id"] = row["updated_by"]
    row["updated_by_username"] = admin_username(row["updated_by"])
    row["updated_by"] = nil
  end
  if not row["updated_by_id"] or row["updated_by_id"] == pg_null then
    row["updated_by_id"] = "00000000-0000-0000-0000-000000000000"
  end
  if not row["updated_by_username"] or row["updated_by_username"] == pg_null then
    row["updated_by_username"] = "Unknown (Imported)"
  end

  local deleted_at = row["deleted_at"]
  if row["deleted_at"] then
    track_delete(table_name, row["id"])
    row["deleted_at"] = nil
  end

  print("INSERT: " .. table_name .. ": " .. inspect(row))

  local result, err = pg_utils.insert(table_name, row)
  if err then
    print("failed to perform postgresql insert: " .. err)
    os.exit(1)
  end

  if after_insert then
    after_insert()
  end

  if deleted_at then
    delete(table_name, { id = row["id"] })
  end

  return result, err
end

local function migrate_collection(name, callback)
  local collection = mongo_database:getCollection(name)
  for row in collection:aggregate('[ { "$sort": { "updated_at": 1 } } ]', { allowDiskUse = true }):iterator() do
    print(inspect(row))

    if type(row["_id"]) == "userdata" and row["_id"].__name == "mongo.ObjectID" then
      local old_id = row["_id"]:hash()
      row["_id"] = uuid_generate()
      print("Migrating ObjectID " .. inspect(old_id) .. " to UUID " .. inspect(row["_id"]))
    end

    callback(row)
  end
end

local function build_admin_username_mappings()
  migrate_collection("admins", function(row)
    admin_usernames[row["_id"]] = row["username"]
  end)
end

local function migrate_admins()
  migrate_collection("admins", function(row)
    row["group_ids"] = nil

    local authentication_token = row["authentication_token"] or random_token(40)
    row["authentication_token_hash"] = hmac(authentication_token)
    local encrypted, iv = encryptor.encrypt(authentication_token, row["_id"])
    row["authentication_token_encrypted"] = encrypted
    row["authentication_token_encrypted_iv"] = iv
    row["authentication_token"] = nil

    row["version"] = nil
    row["registration_source"] = nil

    insert("admins", row)
  end)
end

local function migrate_api_scopes()
  migrate_collection("api_scopes", function(row)
    row["version"] = nil

    insert("api_scopes", row)
  end)
end

local function migrate_admin_groups()
  migrate_collection("admin_groups", function(row)
    local api_scope_ids = row["api_scope_ids"]
    local permission_ids = row["permission_ids"]
    row["api_scope_ids"] = nil
    row["permission_ids"] = nil
    row["version"] = nil

    insert("admin_groups", row, function()
      if api_scope_ids then
        for _, api_scope_id in ipairs(api_scope_ids) do
          insert("admin_groups_api_scopes", {
            admin_group_id = row["id"],
            api_scope_id = api_scope_id,
            created_at = row["created_at"],
            created_by_id = row["created_by_id"],
            created_by_username = row["created_by_username"],
            updated_at = row["updated_at"],
            updated_by_id = row["updated_by_id"],
            updated_by_username = row["updated_by_username"],
          })

          if deletes["api_scopes"] and deletes["api_scopes"][api_scope_id] then
            delete("admin_groups_api_scopes", { admin_group_id = row["id"], api_scope_id = api_scope_id })
          end
        end
      end

      if permission_ids then
        for _, permission_id in ipairs(permission_ids) do
          insert("admin_groups_admin_permissions", {
            admin_group_id = row["id"],
            admin_permission_id = permission_id,
            created_at = row["created_at"],
            created_by_id = row["created_by_id"],
            created_by_username = row["created_by_username"],
            updated_at = row["updated_at"],
            updated_by_id = row["updated_by_id"],
            updated_by_username = row["updated_by_username"],
          })
        end
      end
    end)
  end)
end

local function migrate_api_users()
  migrate_collection("api_users", function(row)
    local api_key = row["api_key"]
    row["api_key_hash"] = hmac(api_key)
    local encrypted, iv = encryptor.encrypt(api_key, row["id"])
    row["api_key_encrypted"] = encrypted
    row["api_key_encrypted_iv"] = iv
    row["api_key_prefix"] = string.sub(api_key, 1, API_KEY_PREFIX_LENGTH)
    row["api_key"] = nil

    local roles = row["roles"]
    local settings = row["settings"]
    row["roles"] = nil
    row["settings"] = nil

    row["__v"] = nil
    row["ts"] = nil
    row["terms_and_conditions"] = nil
    if row["throttle_by_ip"] == mongo.Null then
      row["throttle_by_ip"] = nil
    end
    if row["throttle_daily_limit"] == mongo.Null then
      row["throttle_daily_limit"] = nil
    end
    if row["throttle_hourly_limit"] == mongo.Null then
      row["throttle_hourly_limit"] = nil
    end
    if row["unthrottled"] == mongo.Null or row["unthrottled"] == false then
      row["unthrottled"] = nil
    end
    if type(row["email"]) == "table" then
      if #row["email"] == 1 or (#row["email"] == 2 and is_empty(row["email"][2])) then
        row["email"] = row["email"][1]
      end
    end
    if not row["created_at"] and row["updated_at"] then
      row["created_at"] = row["updated_at"]
    end

    if type(row["email"]) == "string" and string.len(row["email"]) > 255 then
      row["email"] = string.sub(row["email"], 1, 255)
    end
    if type(row["first_name"]) == "string" and string.len(row["first_name"]) > 80 then
      row["first_name"] = string.sub(row["first_name"], 1, 80)
    end
    if type(row["last_name"]) == "string" and string.len(row["last_name"]) > 80 then
      row["last_name"] = string.sub(row["last_name"], 1, 80)
    end
    if type(row["use_description"]) == "string" and string.len(row["use_description"]) > 2000 then
      row["use_description"] = string.sub(row["use_description"], 1, 2000)
    end
    if type(row["website"]) == "string" and string.len(row["website"]) > 255 then
      row["website"] = string.sub(row["website"], 1, 255)
    end
    if type(row["registration_source"]) == "string" and string.len(row["registration_source"]) > 255 then
      row["registration_source"] = string.sub(row["registration_source"], 1, 255)
    end
    if type(row["registration_user_agent"]) == "string" and string.len(row["registration_user_agent"]) > 1000 then
      row["registration_user_agent"] = string.sub(row["registration_user_agent"], 1, 1000)
    end
    if type(row["registration_referer"]) == "string" and string.len(row["registration_referer"]) > 1000 then
      row["registration_referer"] = string.sub(row["registration_referer"], 1, 1000)
    end
    if type(row["registration_origin"]) == "string" and string.len(row["registration_origin"]) > 1000 then
      row["registration_origin"] = string.sub(row["registration_origin"], 1, 1000)
    end

    insert("api_users", row)

    if roles then
      for _, role in ipairs(roles) do
        insert("api_users_roles", {
          api_user_id = row["id"],
          api_role_id = role,
          created_at = row["created_at"],
          created_by_id = row["created_by_id"],
          created_by_username = row["created_by_username"],
          updated_at = row["updated_at"],
          updated_by_id = row["updated_by_id"],
          updated_by_username = row["updated_by_username"],
        })
      end
    end

    if settings then
      settings["api_user_id"] = row["id"]
      settings["created_at"] = row["created_at"]
      settings["created_by_id"] = row["created_by_id"]
      settings["created_by_username"] = row["created_by_username"]
      settings["updated_at"] = row["updated_at"]
      settings["updated_by_id"] = row["updated_by_id"]
      settings["updated_by_username"] = row["updated_by_username"]

      if not is_empty(settings["allowed_referers"]) then
        settings["allowed_referers"] = pg_utils.raw(pg_encode_array(settings["allowed_referers"]))
      end

      if not is_empty(settings["allowed_ips"]) then
        settings["allowed_ips"] = pg_utils.raw(pg_encode_array(settings["allowed_ips"]) .. "::inet[]")
      end

      if is_empty(settings["error_data"]) then
        settings["error_data"] = nil
      end
      if is_empty(settings["error_templates"]) then
        settings["error_templates"] = nil
      end
      if is_empty(settings["rate_limit_mode"]) then
        settings["rate_limit_mode"] = nil
      end

      local rate_limits = settings["rate_limits"]
      settings["rate_limits"] = nil

      insert("api_user_settings", settings)

      if rate_limits then
        for _, rate_limit in ipairs(rate_limits) do
          rate_limit["api_user_settings_id"] = settings["id"]
          rate_limit["created_at"] = row["created_at"]
          rate_limit["created_by_id"] = row["created_by_id"]
          rate_limit["created_by_username"] = row["created_by_username"]
          rate_limit["updated_at"] = row["updated_at"]
          rate_limit["updated_by_id"] = row["updated_by_id"]
          rate_limit["updated_by_username"] = row["updated_by_username"]
        end
      end
    end
  end)
end

local function run()
  args = parse_args()
  seed_database.seed_once()

  mongo_client = mongo.Client(args["mongodb_url"])
  mongo_database = mongo_client:getDefaultDatabase()
  pg_utils.db_config["user"] = "api-umbrella"

  query("START TRANSACTION")
  query("SET CONSTRAINTS ALL DEFERRED")
  query("SET SESSION api_umbrella.disable_stamping = 'on'")

  if args["clean"] then
    query("TRUNCATE TABLE admins, api_scopes, admin_groups, audit.log CASCADE")
  end

  build_admin_username_mappings()
  migrate_admins()
  migrate_api_scopes()
  migrate_admin_groups()
  migrate_api_users()

  query("COMMIT")
end

run()
