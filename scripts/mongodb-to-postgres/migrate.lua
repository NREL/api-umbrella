local aes = require "resty.aes"
local argparse = require "argparse"
local cbson = require "cbson"
local cjson = require "cjson"
local encryptor = require "api-umbrella.utils.encryptor"
local hmac = require "api-umbrella.utils.hmac"
local icu_date = require "icu-date"
local inspect = require "inspect"
local is_empty = require("pl.types").is_empty
local moongoo = require "resty.moongoo"
local pg_encode_array = require "api-umbrella.utils.pg_encode_array"
local pg_encode_bytea = require("pgmoon").Postgres.encode_bytea
local pg_encode_json = require("pgmoon.json").encode_json
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
local object_ids = {}
local format_iso8601 = icu_date.formats.iso8601()
local json_decode = cjson.decode
local json_null = cjson.null
local mongo_client
local mongo_database

random_seed()

local function parse_args()
  local parser = argparse("api-umbrella", "Open source API management")

  parser:option("--mongodb-url", "Input MongoDB database URL."):count(1)
  parser:option("--pg-host", "Output PostgreSQL database host."):count(1)
  parser:option("--pg-port", "Output PostgreSQL database port."):count(1)
  parser:option("--pg-database", "Output PostgreSQL database name."):count(1)
  parser:option("--pg-user", "Output PostgreSQL connection username."):count(1)
  parser:option("--pg-password", "Output PostgreSQL connection password."):count(1)
  parser:option("--auto-ssl-encryption-secret", "Output PostgreSQL connection password.")
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

local function convert_mongo_types(table)
  if not table then return end

  for key, value in pairs(table) do
    if value == json_null then
      table[key] = pg_null
    elseif type(value) == "table" and #value == 0 then
      local bson_index = 1
      for bson_key, bson_value in pairs(value) do
        if bson_index > 1 then
          break
        end

        if bson_key == "$oid" then
          local old_id = bson_value
          if object_ids[old_id] then
            table[key] = object_ids[old_id]
            -- print("USING ObjectID " .. inspect(old_id) .. " to UUID " .. inspect(table[key]))
          else
            table[key] = uuid_generate()
            object_ids[old_id] = table[key]
            -- print("Migrating ObjectID " .. inspect(old_id) .. " to UUID " .. inspect(table[key]))
          end
        elseif bson_key == "$date" then
          date:set_millis(bson_value)
          table[key] = date:format(format_iso8601)
        elseif bson_key == "$timestamp" then
          date:set_millis(bson_value["t"] * 1000)
          table[key] = date:format(format_iso8601)
        elseif string.sub(bson_key, 1, 1) == "$" then
          print(inspect(table))
          error("Unknown handling for BSON type: " .. bson_key .. " " .. key .. "=" .. inspect(value))
        end

        bson_index = bson_index + 1
      end
    end

    if type(table[key]) == "string" then
      -- Strip null byte characters that aren't allowed in Postgres.
      table[key] = ngx.re.gsub(table[key], [[\0]], "", "jo")
    elseif type(table[key]) == "table" then
      table[key] = convert_mongo_types(table[key])
    end
  end

  return table
end

local function convert_json_nulls(table)
  if not table then return end

  local new_table = {}
  for key, value in pairs(table) do
    if value == pg_null then
      new_table[key] = json_null
    elseif type(value) == "table" then
      new_table[key] = convert_json_nulls(value)
    else
      new_table[key] = value
    end
  end

  return new_table
end

local function query(...)
  local result, err = pg_utils.query(...)
  if err then
    print("failed to perform postgresql query: " .. err)
    print(inspect(...))
    os.exit(1)
  end

  return result, err
end

local function delete(table_name, where)
  -- print("DELETE: " .. table_name .. ": " .. inspect(where))
  local result, err = pg_utils.delete(table_name, where)
  if err then
    print("failed to perform postgresql delete: " .. err)
    print(inspect(table_name))
    print(inspect(where))
    os.exit(1)
  end

  return result, err
end

local function insert(table_name, row, after_insert)
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

  local deleted_at
  if row["deleted_at"] and row["deleted_at"] ~= pg_null then
    deleted_at = row["deleted_at"]
    track_delete(table_name, row["id"])
  end
  row["deleted_at"] = nil

  if table_name == "analytics_cities" or table_name == "distributed_rate_limit_counters" or table_name == "auto_ssl_storage" or table_name == "legacy_log" then
    row["created_by_id"] = nil
    row["created_by_username"] = nil
    row["updated_by_id"] = nil
    row["updated_by_username"] = nil
  end

  -- print("INSERT: " .. table_name .. ": " .. inspect(row))

  local result, err = pg_utils.insert(table_name, row)
  if err then
    print("failed to perform postgresql insert: " .. err)
    print(inspect(table_name))
    print(inspect(row))
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

local function upsert_role(row)
  -- print("UPSERT: api_roles: " .. inspect(row))
  return query("INSERT INTO api_roles (id, created_at, created_by_id, created_by_username, updated_at, updated_by_id, updated_by_username) VALUES (:id, :created_at, :created_by_id, :created_by_username, :updated_at, :updated_by_id, :updated_by_username) ON CONFLICT (id) DO UPDATE SET updated_at = EXCLUDED.updated_at, updated_by_id = EXCLUDED.updated_by_id, updated_by_username = EXCLUDED.updated_by_username", row)
end

local function migrate_collection(name, callback)
  print("Migrating collection " .. inspect(name) .. "...")

  local collection = mongo_database:collection(name)
  local agg = {
    {
      ["$sort"] = {
        updated_at = 1,
      },
    },
  }
  if name == "config_versions" then
    agg[1]["$sort"] = {
      version = -1,
    }
  end
  local cursor, err = collection:aggregate(agg, { allowDiskUse = true })
  if err then
    error(err)
  end
  local row = cursor:next()
  while row do
    io.write(".")
    io.flush()
    row = json_decode(cbson.to_json(cbson.encode(row)))
    -- print(inspect(row))

    convert_mongo_types(row)

    callback(row)

    row = cursor:next()
  end
  print("")
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

local function insert_settings(table_name, row, settings)
  settings["created_at"] = row["created_at"]
  settings["created_by_id"] = row["created_by_id"]
  settings["created_by_username"] = row["created_by_username"]
  settings["updated_at"] = row["updated_at"]
  settings["updated_by_id"] = row["updated_by_id"]
  settings["updated_by_username"] = row["updated_by_username"]

  if table_name == "api_user_settings" and is_empty(settings["error_data"]) then
    settings["error_data"] = nil
  elseif settings["error_data"] and settings["error_data"] ~= pg_null then
    settings["error_data"] = pg_utils.raw(pg_encode_json(convert_json_nulls(settings["error_data"])))
  end

  if table_name == "api_user_settings" and is_empty(settings["error_templates"]) then
    settings["error_templates"] = nil
  elseif settings["error_templates"] and settings["error_templates"] ~= pg_null then
    settings["error_templates"] = pg_utils.raw(pg_encode_json(convert_json_nulls(settings["error_templates"])))
  end

  if settings["allowed_ips"] and settings["allowed_ips"] ~= pg_null then
    settings["allowed_ips"] = pg_utils.raw(pg_encode_array(settings["allowed_ips"]) .. "::inet[]")
  end

  if settings["allowed_referers"] and settings["allowed_referers"] ~= pg_null then
    settings["allowed_referers"] = pg_utils.raw(pg_encode_array(settings["allowed_referers"]))
  end

  if settings["require_https"] == "required_return_redirect" then
    settings["require_https"] = "required_return_error"
  end

  if settings["hourly_rate_limit"] == pg_null then
    settings["hourly_rate_limit"] = nil
  end

  if settings["rate_limit_mode"] == "" then
    settings["rate_limit_mode"] = nil
  end

  local rate_limits = settings["rate_limits"]
  settings["rate_limits"] = nil

  local required_roles = settings["required_roles"]
  settings["required_roles"] = nil

  local headers = {}

  headers["request"] = settings["headers"]
  settings["headers"] = nil

  headers["response_default"] = settings["default_response_headers"]
  settings["default_response_headers"] = nil

  headers["response_override"] = settings["override_response_headers"]
  settings["override_response_headers"] = nil

  insert(table_name, settings, function()
    if rate_limits then
      for _, rate_limit in ipairs(rate_limits) do
        if table_name == "api_user_settings" then
          rate_limit["api_user_settings_id"] = settings["id"]
        else
          rate_limit["api_backend_settings_id"] = settings["id"]
        end
        if not rate_limit["limit_to"] then
          rate_limit["limit_to"] = rate_limit["limit"]
          rate_limit["limit"] = nil
        end
        if rate_limit["limit_by"] == "apiKey" then
          rate_limit["limit_by"] = "api_key"
        end
        if rate_limit["response_headers"] == pg_null then
          rate_limit["response_headers"] = false
        end
        rate_limit["created_at"] = row["created_at"]
        rate_limit["created_by_id"] = row["created_by_id"]
        rate_limit["created_by_username"] = row["created_by_username"]
        rate_limit["updated_at"] = row["updated_at"]
        rate_limit["updated_by_id"] = row["updated_by_id"]
        rate_limit["updated_by_username"] = row["updated_by_username"]

        insert("rate_limits", rate_limit)
      end
    end

    if required_roles then
      for _, role in ipairs(required_roles) do
        if role ~= "" then
          upsert_role({
            id = role,
            created_at = row["created_at"],
            created_by_id = row["created_by_id"],
            created_by_username = row["created_by_username"],
            updated_at = row["updated_at"],
            updated_by_id = row["updated_by_id"],
            updated_by_username = row["updated_by_username"],
          })

          insert("api_backend_settings_required_roles", {
            api_backend_settings_id = settings["id"],
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
    end

    for header_type, type_headers in ipairs(headers) do
      for index, header in ipairs(type_headers) do
        header["api_backend_settings_id"] = settings["id"]
        header["header_type"] = header_type
        header["sort_order"] = index
        header["created_at"] = row["created_at"]
        header["created_by_id"] = row["created_by_id"]
        header["created_by_username"] = row["created_by_username"]
        header["updated_at"] = row["updated_at"]
        header["updated_by_id"] = row["updated_by_id"]
        header["updated_by_username"] = row["updated_by_username"]

        insert("api_backend_http_headers", header)
      end
    end
  end)
end

local function migrate_api_backends()
  migrate_collection("apis", function(row)
    local settings = row["settings"]
    row["settings"] = nil

    local servers = row["servers"]
    row["servers"] = nil

    local url_matches = row["url_matches"]
    row["url_matches"] = nil

    local sub_settings = row["sub_settings"]
    row["sub_settings"] = nil

    local rewrites = row["rewrites"]
    row["rewrites"] = nil

    row["version"] = nil
    row["default_response_headers"] = nil
    row["override_response_headers"] = nil

    insert("api_backends", row, function()
      if servers then
        for _, server in ipairs(servers) do
          server["api_backend_id"] = row["id"]
          server["created_at"] = row["created_at"]
          server["created_by_id"] = row["created_by_id"]
          server["created_by_username"] = row["created_by_username"]
          server["updated_at"] = row["updated_at"]
          server["updated_by_id"] = row["updated_by_id"]
          server["updated_by_username"] = row["updated_by_username"]

          insert("api_backend_servers", server)
        end
      end

      if url_matches then
        local seen_url_matches = {}
        local index = 1
        for _, url_match in ipairs(url_matches) do
          local key = (url_match["frontend_prefix"] or "") .. (url_match["backend_prefix"] or "")
          if not seen_url_matches[key] then
            url_match["api_backend_id"] = row["id"]
            url_match["sort_order"] = index
            url_match["created_at"] = row["created_at"]
            url_match["created_by_id"] = row["created_by_id"]
            url_match["created_by_username"] = row["created_by_username"]
            url_match["updated_at"] = row["updated_at"]
            url_match["updated_by_id"] = row["updated_by_id"]
            url_match["updated_by_username"] = row["updated_by_username"]

            insert("api_backend_url_matches", url_match)

            seen_url_matches[key] = true
            index = index + 1
          end
        end
      end

      if settings then
        settings["api_backend_id"] = row["id"]
        insert_settings("api_backend_settings", row, settings)
      end

      if sub_settings then
        for index, sub_setting in ipairs(sub_settings) do
          sub_setting["api_backend_id"] = row["id"]
          sub_setting["sort_order"] = index
          sub_setting["created_at"] = row["created_at"]
          sub_setting["created_by_id"] = row["created_by_id"]
          sub_setting["created_by_username"] = row["created_by_username"]
          sub_setting["updated_at"] = row["updated_at"]
          sub_setting["updated_by_id"] = row["updated_by_id"]
          sub_setting["updated_by_username"] = row["updated_by_username"]

          local sub_setting_settings = sub_setting["settings"]
          sub_setting["settings"] = nil

          if not sub_setting["regex"] and deletes["api_backends"] and deletes["api_backends"][row["id"]] then
            sub_setting["regex"] = "^$"
          end

          insert("api_backend_sub_url_settings", sub_setting)

          if sub_setting_settings then
            sub_setting_settings["api_backend_sub_url_settings_id"] = sub_setting["id"]
            insert_settings("api_backend_settings", row, sub_setting_settings)
          end
        end
      end

      if rewrites then
        for index, rewrite in ipairs(rewrites) do
          rewrite["api_backend_id"] = row["id"]
          rewrite["sort_order"] = index
          rewrite["created_at"] = row["created_at"]
          rewrite["created_by_id"] = row["created_by_id"]
          rewrite["created_by_username"] = row["created_by_username"]
          rewrite["updated_at"] = row["updated_at"]
          rewrite["updated_by_id"] = row["updated_by_id"]
          rewrite["updated_by_username"] = row["updated_by_username"]

          insert("api_backend_rewrites", rewrite)
        end
      end

    end)
  end)
end

local function migrate_api_users()
  migrate_collection("api_users", function(row)
    local api_key = row["api_key"]
    row["api_key_hash"] = hmac(api_key)
    local encrypted, iv = encryptor.encrypt(api_key, row["_id"])
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
    if row["throttle_by_ip"] == pg_null then
      row["throttle_by_ip"] = nil
    end
    if row["throttle_daily_limit"] == pg_null then
      row["throttle_daily_limit"] = nil
    end
    if row["throttle_hourly_limit"] == pg_null then
      row["throttle_hourly_limit"] = nil
    end
    if row["unthrottled"] == pg_null or row["unthrottled"] == false then
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

    insert("api_users", row, function()
      if roles then
        for _, role in ipairs(roles) do
          if role ~= "" then
            upsert_role({
              id = role,
              created_at = row["created_at"],
              created_by_id = row["created_by_id"],
              created_by_username = row["created_by_username"],
              updated_at = row["updated_at"],
              updated_by_id = row["updated_by_id"],
              updated_by_username = row["updated_by_username"],
            })

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
      end

      if settings then
        settings["api_user_id"] = row["id"]
        insert_settings("api_user_settings", row, settings)
      end
    end)
  end)
end

local function migrate_published_config()
  migrate_collection("config_versions", function(row)
    row["config"] = pg_utils.raw(pg_encode_json(convert_json_nulls(row["config"])))
    row["_id"] = nil
    row["version"] = nil

    insert("published_config", row)
  end)
end

local function migrate_distributed_rate_limit_counters()
  migrate_collection("rate_limits", function(row)
    row["expires_at"] = row["expire_at"]
    row["expire_at"] = nil
    row["value"] = row["count"]
    row["count"] = nil
    row["ts"] = nil
    insert("distributed_rate_limit_counters", row)
  end)
end

local function migrate_audit_legacy_log()
  query("SET search_path = audit, public")
  migrate_collection("mongoid_delorean_histories", function(row)
    row["_id"] = nil

    if row["altered_attributes"] and row["altered_attributes"] ~= pg_null then
      row["altered_attributes"] = pg_utils.raw(pg_encode_json(convert_json_nulls(row["altered_attributes"])))
    end

    if row["full_attributes"] and row["full_attributes"] ~= pg_null then
      row["full_attributes"] = pg_utils.raw(pg_encode_json(convert_json_nulls(row["full_attributes"])))
    end

    insert("legacy_log", row)
  end)
  query("SET search_path = api_umbrella, public")
end

local function migrate_analytics_cities()
  migrate_collection("log_city_locations", function(row)
    row["_id"] = nil
    row["location"] = pg_utils.raw("point(" .. pg_utils.escape_literal(row["location"]["coordinates"][1]) .. "," .. pg_utils.escape_literal(row["location"]["coordinates"][2]) .. ")")

    insert("analytics_cities", row)
  end)
end

local function migrate_auto_ssl_storage()
  migrate_collection("ssl_certs", function(row)
    row["key"] = row["_id"]
    row["_id"] = nil

    local aes_instance = assert(aes:new(args["auto_ssl_encryption_secret"], nil, aes.cipher(256, "cbc"), { iv = row["encryption_iv"] }))
    local value = aes_instance:decrypt(ngx.decode_base64(row["encrypted_value"]))
    if not value then
      error("decryption failed")
    end

    local encrypted, iv = encryptor.encrypt(value, row["key"], { base64 = false })
    row["value_encrypted"] = pg_utils.raw(pg_encode_bytea(nil, encrypted))
    row["value_encrypted_iv"] = iv
    row["encrypted_value"] = nil
    row["encryption_iv"] = nil
    row["created_at"] = pg_utils.raw("now()")
    row["updated_at"] = pg_utils.raw("now()")

    insert("auto_ssl_storage", row)
  end)
end

local function run()
  args = parse_args()
  seed_database.seed_once()

  local err
  mongo_client, err = moongoo.new(args["mongodb_url"])
  if not mongo_client then
    error(err)
  end
  mongo_database = mongo_client:db("api_umbrella_production")
  pg_utils.db_config["host"] = args["pg_host"]
  pg_utils.db_config["port"] = args["pg_port"]
  pg_utils.db_config["database"] = args["pg_database"]
  pg_utils.db_config["user"] = args["pg_user"]
  pg_utils.db_config["password"] = args["pg_password"]

  query("START TRANSACTION")
  query("SET CONSTRAINTS ALL DEFERRED")
  query("SET SESSION api_umbrella.disable_stamping = 'on'")

  if args["clean"] then
    query("TRUNCATE TABLE admin_groups, admins, analytics_cities, api_backends, api_roles, api_scopes, api_users, auto_ssl_storage, distributed_rate_limit_counters, audit.log CASCADE")
  end

  build_admin_username_mappings()
  migrate_audit_legacy_log()
  migrate_distributed_rate_limit_counters()
  migrate_admins()
  migrate_api_scopes()
  migrate_admin_groups()
  migrate_api_backends()
  migrate_api_users()
  migrate_published_config()
  migrate_analytics_cities()
  migrate_auto_ssl_storage()

  query("COMMIT")
end

run()
