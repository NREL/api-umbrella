local aes = require "resty.aes"
local api_key_prefixer = require("api-umbrella.utils.api_key_prefixer").prefix
local argparse = require "argparse"
local cbson = require "cbson"
local cjson = require "cjson"
local encryptor = require "api-umbrella.utils.encryptor"
local hmac = require "api-umbrella.utils.hmac"
local icu_date = require "icu-date-ffi"
local inspect = require "inspect"
local is_empty = require "api-umbrella.utils.is_empty"
local moongoo = require "resty.moongoo"
local pg_encode_array = require "api-umbrella.utils.pg_encode_array"
local pg_encode_bytea = require("pgmoon").Postgres.encode_bytea
local pg_encode_json = require("pgmoon.json").encode_json
local pg_null = require("pgmoon").Postgres.NULL
local pg_utils = require "api-umbrella.utils.pg_utils"
local random_seed = require "api-umbrella.utils.random_seed"
local random_token = require "api-umbrella.utils.random_token"
local seed_database = require "api-umbrella.proxy.startup.seed_database"
local split = require("ngx.re").split
local utf8 = require "lua-utf8"
local uuid_generate = require("resty.uuid").generate_random

local admin_usernames = {}
local api_key_user_ids = {}
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

  if table["_id"] then
    table["id"] = table["_id"]
    table["_id"] = nil
  end

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

local function insert(table_name, row, last_imported_at, after_insert)
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

  if last_imported_at then
    local result, err = query("SELECT * FROM " .. pg_utils.escape_identifier(table_name) .. " WHERE id = :id", { id = row["id"] })
    if err then
      error(err)
    elseif result and result[1] then
      local old_row = result[1]
      local old_json = cjson.encode(old_row)
      local new_json = cjson.encode(row)

      date:parse(format_iso8601, old_row["updated_at"])
      local old_row_updated_at = date:get_millis()
      if old_row_updated_at > last_imported_at then
        print("\nERROR: Row in PostgreSQL has a newer updated_at timestamp than row in Mongo")
        print("Old Row: " .. old_json)
        print("New Row: " .. new_json)
        return
      else
        print("\nReplacing row: " .. row["id"])
        print("Old Row: " .. old_json)
        print("New Row: " .. new_json)
        delete(table_name, { id = row["id"] })
      end
    else
      print("\nAppending row: " .. (row["id"] or row["updated_at"]))
    end
  end

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

local function loop_collection(name, callback)
  local collection = mongo_database:collection(name)

  local agg = {
    {
      ["$sort"] = {
        updated_at = 1,
      },
    },
  }
  local cursor, err = collection:aggregate(agg, { allowDiskUse = true })
  if err then
    error(err)
  end
  local row = cursor:next()
  while row do
    row = json_decode(cbson.to_json(cbson.encode(row)))

    convert_mongo_types(row)

    callback(row)

    row = cursor:next()
  end
end

local function migrate_collection(name, callback)
  print("Migrating collection " .. inspect(name) .. "...")

  local cache_last_imported_key = "mongodb_last_imported_timestamp:" .. name
  local last_imported_results, last_imported_err = query("SELECT data FROM api_umbrella.cache WHERE id = :id", { id = cache_last_imported_key })
  if last_imported_err then
    error(last_imported_err)
  end

  local collection = mongo_database:collection(name)

  local agg = {}
  local last_imported_at
  if last_imported_results and last_imported_results[1] then
    date:parse(format_iso8601, last_imported_results[1]["data"])
    last_imported_at = date:get_millis()
    table.insert(agg, {
      ["$match"] = {
        updated_at = {
          ["$gt"] = cbson.date(last_imported_at),
        },
      },
    })
  end

  local sort_field = "updated_at"
  if name == "config_versions" then
    sort_field = "version"
  end
  table.insert(agg, {
    ["$sort"] = {
      [sort_field] = 1,
    },
  })

  -- if name == "mongoid_delorean_histories" then
  --   table.insert(agg, {
  --     ["$limit"] = 1000,
  --   })
  -- end

  local cursor, err = collection:aggregate(agg, { allowDiskUse = true })
  if err then
    error(err)
  end
  local last_imported_timestamp
  local row = cursor:next()
  while row do
    io.write(".")
    io.flush()
    row = json_decode(cbson.to_json(cbson.encode(row)))
    -- print(inspect(row))

    convert_mongo_types(row)

    last_imported_timestamp = row["updated_at"]

    callback(row, last_imported_at)

    row = cursor:next()
  end
  print("")

  if last_imported_timestamp then
    query("INSERT INTO api_umbrella.cache (id, data) VALUES (:id, :data) ON CONFLICT (id) DO UPDATE SET data = EXCLUDED.data", {
      id = cache_last_imported_key,
      data = last_imported_timestamp,
    })
  end
end

local function build_admin_username_mappings()
  loop_collection("admins", function(row)
    admin_usernames[row["id"]] = row["username"]
  end)
end

local function migrate_admins()
  migrate_collection("admins", function(row, last_imported_at)
    local group_ids = row["group_ids"]
    row["group_ids"] = nil

    local authentication_token = row["authentication_token"] or random_token(40)
    row["authentication_token_hash"] = hmac(authentication_token)
    local encrypted, iv = encryptor.encrypt(authentication_token, row["id"])
    row["authentication_token_encrypted"] = encrypted
    row["authentication_token_encrypted_iv"] = iv
    row["authentication_token"] = nil

    row["version"] = nil
    row["registration_source"] = nil

    insert("admins", row, last_imported_at, function()
      if group_ids then
        for _, group_id in ipairs(group_ids) do
          insert("admin_groups_admins", {
            admin_group_id = group_id,
            admin_id = row["id"],
            created_at = row["created_at"],
            created_by_id = row["created_by_id"],
            created_by_username = row["created_by_username"],
            updated_at = row["updated_at"],
            updated_by_id = row["updated_by_id"],
            updated_by_username = row["updated_by_username"],
          })

          if deletes["admin_groups"] and deletes["admin_groups"][group_id] then
            delete("admin_groups_admins", { admin_group_id = group_id, admin_id = row["id"] })
          end
        end
      end
    end)
  end)
end

local function migrate_api_scopes()
  migrate_collection("api_scopes", function(row, last_imported_at)
    row["version"] = nil

    insert("api_scopes", row, last_imported_at)
  end)
end

local function migrate_admin_groups()
  migrate_collection("admin_groups", function(row, last_imported_at)
    local api_scope_ids = row["api_scope_ids"]
    local permission_ids = row["permission_ids"]
    row["api_scope_ids"] = nil
    row["permission_ids"] = nil
    row["version"] = nil

    insert("admin_groups", row, last_imported_at, function()
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

  insert(table_name, settings, nil, function()
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

    if required_roles and required_roles ~= pg_null then
      for _, role in ipairs(required_roles) do
        if role ~= "" and role ~= pg_null then
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

    for header_type, type_headers in pairs(headers) do
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
  migrate_collection("apis", function(row, last_imported_at)
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

    insert("api_backends", row, last_imported_at, function()
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
  migrate_collection("api_users", function(row, last_imported_at)
    api_key_user_ids[row["api_key"]] = row["id"]

    local api_key = row["api_key"]
    row["api_key_hash"] = hmac(api_key)
    local encrypted, iv = encryptor.encrypt(api_key, row["id"])
    row["api_key_encrypted"] = encrypted
    row["api_key_encrypted_iv"] = iv
    row["api_key_prefix"] = api_key_prefixer(api_key)
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
      row["email"] = utf8.sub(row["email"], 1, 255)
    end
    if type(row["first_name"]) == "string" and string.len(row["first_name"]) > 80 then
      row["first_name"] = utf8.sub(row["first_name"], 1, 80)
    end
    if type(row["last_name"]) == "string" and string.len(row["last_name"]) > 80 then
      row["last_name"] = utf8.sub(row["last_name"], 1, 80)
    end
    if type(row["use_description"]) == "string" and string.len(row["use_description"]) > 2000 then
      row["use_description"] = utf8.sub(row["use_description"], 1, 2000)
    end
    if type(row["website"]) == "string" and string.len(row["website"]) > 255 then
      row["website"] = utf8.sub(row["website"], 1, 255)
    end
    if type(row["registration_source"]) == "string" and string.len(row["registration_source"]) > 255 then
      row["registration_source"] = utf8.sub(row["registration_source"], 1, 255)
    end
    if type(row["registration_user_agent"]) == "string" and string.len(row["registration_user_agent"]) > 1000 then
      row["registration_user_agent"] = utf8.sub(row["registration_user_agent"], 1, 1000)
    end
    if type(row["registration_referer"]) == "string" and string.len(row["registration_referer"]) > 1000 then
      row["registration_referer"] = utf8.sub(row["registration_referer"], 1, 1000)
    end
    if type(row["registration_origin"]) == "string" and string.len(row["registration_origin"]) > 1000 then
      row["registration_origin"] = utf8.sub(row["registration_origin"], 1, 1000)
    end

    insert("api_users", row, last_imported_at, function()
      if roles and roles ~= pg_null then
        for _, role in ipairs(roles) do
          if role ~= "" and role ~= pg_null then
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

local function migrate_website_backends()
  local hosts = {}
  migrate_collection("website_backends", function(row, last_imported_at)
    row["version"] = nil

    -- The old system allowed duplicates (which wasn't really valid), while the
    -- postgres database does not. So let the last website backend win during
    -- import.
    if hosts[row["frontend_host"]] then
      delete("website_backends", { frontend_host = row["frontend_host"] })
    end
    hosts[row["frontend_host"]] = true


    insert("website_backends", row, last_imported_at)
  end)
end

local function convert_published_settings(settings)
  if not settings then
    return
  end

  if settings["pass_api_key_header"] == nil then
    settings["pass_api_key_header"] = false
  end

  if settings["pass_api_key_query_param"] == nil then
    settings["pass_api_key_query_param"] = false
  end

  if settings["redirect_https"] == nil then
    settings["redirect_https"] = false
  end

  if settings["required_roles_override"] == nil then
    settings["required_roles_override"] = false
  end

  if settings["rate_limits"] then
    for _, rate_limit in ipairs(settings["rate_limits"]) do
      if rate_limit["response_headers"] == nil then
        rate_limit["response_headers"] = false
      end
    end

    table.sort(settings["rate_limits"], function(a, b)
      if a["duration"] == b["duration"] then
        return a["limit_by"] < b["limit_by"]
      else
        return a["duration"] < b["duration"]
      end
    end)

    if #settings["rate_limits"] == 0 then
      settings["rate_limits"] = nil
    end
  end
end

local function migrate_published_config()
  migrate_collection("config_versions", function(row, last_imported_at)
    if row["config"]["apis"] then
      for _, api in ipairs(row["config"]["apis"]) do
        api["default_response_headers"] = nil
        api["override_response_headers"] = nil

        convert_published_settings(api["settings"])

        if api["sub_settings"] then
          for _, sub_setting in ipairs(api["sub_settings"]) do
            convert_published_settings(sub_setting["settings"])
          end

          if #api["sub_settings"] == 0 then
            api["sub_settings"] = nil
          end
        end

        if api["rewrites"] and #api["rewrites"] == 0 then
          api["rewrites"] = nil
        end
      end
    end

    row["config"] = pg_utils.raw(pg_encode_json(convert_json_nulls(row["config"])))
    row["id"] = nil
    row["version"] = nil

    insert("published_config", row, last_imported_at)
  end)
end

local function migrate_distributed_rate_limit_counters()
  migrate_collection("rate_limits", function(row, last_imported_at)
    local id_parts = split(row["id"], ":", "jo")
    if id_parts[1] == "apiKey" then
      id_parts[1] = "api_key"
      local user_id = api_key_user_ids[id_parts[3]]
      if user_id then
        id_parts[3] = user_id
      end
    end
    row["id"] = table.concat(id_parts, ":")
    row["expires_at"] = row["expire_at"]
    row["expire_at"] = nil
    row["value"] = row["count"]
    row["count"] = nil
    row["ts"] = nil
    insert("distributed_rate_limit_counters", row, last_imported_at)
  end)
end

local function migrate_audit_legacy_log()
  query("SET search_path = audit, public")
  migrate_collection("mongoid_delorean_histories", function(row, last_imported_at)
    row["id"] = nil

    if row["altered_attributes"] and row["altered_attributes"] ~= pg_null then
      row["altered_attributes"] = pg_utils.raw(pg_encode_json(convert_json_nulls(row["altered_attributes"])))
    end

    if row["full_attributes"] and row["full_attributes"] ~= pg_null then
      row["full_attributes"] = pg_utils.raw(pg_encode_json(convert_json_nulls(row["full_attributes"])))
    end

    insert("legacy_log", row, last_imported_at)
  end)
  query("SET search_path = api_umbrella, public")
end

local function migrate_analytics_cities()
  migrate_collection("log_city_locations", function(row, last_imported_at)
    row["id"] = nil
    row["location"] = pg_utils.raw("point(" .. pg_utils.escape_literal(row["location"]["coordinates"][1]) .. "," .. pg_utils.escape_literal(row["location"]["coordinates"][2]) .. ")")

    if row["country"] then
      insert("analytics_cities", row, last_imported_at)
    end
  end)
end

local function migrate_auto_ssl_storage()
  migrate_collection("ssl_certs", function(row, last_imported_at)
    row["key"] = row["id"]
    row["id"] = nil

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

    insert("auto_ssl_storage", row, last_imported_at)
  end)
end

local function run()
  args = parse_args()

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

  seed_database.seed_once()

  query("START TRANSACTION")
  query("SET CONSTRAINTS ALL DEFERRED")
  query("SET SESSION api_umbrella.disable_stamping = 'on'")

  if args["clean"] then
    query("TRUNCATE TABLE admin_groups, admins, analytics_cities, api_backends, api_roles, api_scopes, api_users, website_backends, published_config, cache, auto_ssl_storage, distributed_rate_limit_counters, audit.log, audit.legacy_log CASCADE")
  end

  build_admin_username_mappings()
  migrate_api_scopes()
  migrate_admin_groups()
  migrate_admins()
  migrate_api_backends()
  migrate_website_backends()
  migrate_api_users()
  if args["clean"] then
    migrate_published_config()
    migrate_analytics_cities()
    migrate_distributed_rate_limit_counters()
    migrate_auto_ssl_storage()
  end
  migrate_audit_legacy_log()

  query("COMMIT")
end

run()
