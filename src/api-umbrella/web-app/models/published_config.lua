local ApiBackend = require "api-umbrella.web-app.models.api_backend"
local WebsiteBackend = require "api-umbrella.web-app.models.website_backend"
local api_backend_policy = require "api-umbrella.web-app.policies.api_backend_policy"
local cjson = require("cjson")
local db = require "lapis.db"
local is_array = require "api-umbrella.utils.is_array"
local is_empty = require "api-umbrella.utils.is_empty"
local is_hash = require "api-umbrella.utils.is_hash"
local json_null_default = require "api-umbrella.web-app.utils.json_null_default"
local model_ext = require "api-umbrella.web-app.utils.model_ext"
local pg_encode_json = require("pgmoon.json").encode_json
local preload = require("lapis.db.model").preload
local pretty_yaml_dump = require "api-umbrella.web-app.utils.pretty_yaml_dump"
local tablex = require "pl.tablex"
local website_backend_policy = require "api-umbrella.web-app.policies.website_backend_policy"

local db_null = db.NULL
local db_raw = db.raw
local deepcompare = tablex.deepcompare
local deepcopy = tablex.deepcopy
local json_null = cjson.null
local re_find = ngx.re.find
local table_values = tablex.values

local as_json_options = {
  -- Normally we want as_json to return empty array for array fields (so it's
  -- always a consistent type). However, when we're serializing all the records
  -- for publishing, we prefer to remove any empty array in the serialized
  -- data. This is to prevent the empty arrays from overriding higher-level
  -- config when the various configuration options get merged (for example, an
  -- API backend an empty list of custom rate limits should not override the
  -- default rate limits).
  nullify_empty_arrays = true,

  -- Customize the as_json output to exclude some computed fields that
  -- shouldn't be part of the published json.
  for_publishing = true,
}

local PublishedConfig = model_ext.new_class("published_config", {
}, {
  authorize = function()
    return true
  end,

  before_validate_on_create = function(_, values)
    values["id"] = nil
  end,

  before_save = function(_, values)
    if is_hash(values["config"]) and values["config"] ~= db_null then
      values["config"] = db_raw(pg_encode_json(values["config"]))
    end
  end,
})

PublishedConfig.active = function()
  return PublishedConfig:select("ORDER BY id DESC LIMIT 1")[1]
end

PublishedConfig.active_config = function()
  local published = PublishedConfig.active()
  if published then
    return published.config
  else
    return nil
  end
end

local compare_exclude_keys = {
  created_at = 1,
  created_by = 1,
  created_by_id = 1,
  created_by_username = 1,
  created_order = 1,
  creator = 1,
  id = 1,
  name = 1,
  updated_at = 1,
  updated_by = 1,
  updated_by_id = 1,
  updated_by_username = 1,
  updater = 1,
  version = 1,
}
local function config_for_comparison(object)
  local compare_object = object

  if compare_object == json_null then
    return nil
  end

  if is_hash(object) then
    compare_object = {}
    for key, value in pairs(object) do
      -- Exclude various keys and any "*_id" fields from the comparison record.
      if not compare_exclude_keys[key] then
        local find_from, _, find_err = re_find(key, "_ids?$", "jo")
        if find_err then
          ngx.log(ngx.ERR, "regex error: ", find_err)
        end
        if not find_from then
          compare_object[key] = config_for_comparison(value)
        end
      end
    end

    -- If we end up with an empty record and the only value inside the original
    -- object was an "id" field, then include it (even though ids are normally
    -- excluded) so there's something to compare.
    if not next(compare_object) and object["id"] then
      compare_object["id"] = object["id"]
    end
  elseif is_array(object) then
    compare_object = {}
    for index, value in ipairs(object) do
      compare_object[index] = config_for_comparison(value)
    end
  end

  return compare_object
end

local function model_pending_changes_json(active_records_config, model, policy, current_admin)
  assert(active_records_config)
  assert(model)
  assert(policy)
  assert(current_admin)

  local policy_permission_id = "backend_publish"
  local where = policy.authorized_query_scope(current_admin, policy_permission_id)

  local pending_records_config = {}
  local pending_records_config_by_id = {}
  local pending_records_compare_config_by_id = {}
  local pending_records = model.all_sorted(where)

  if model == ApiBackend then
    preload(pending_records, ApiBackend.preload_for_as_json(current_admin))
  end

  for _, record in ipairs(pending_records) do
    local config = record:as_json(as_json_options)
    table.insert(pending_records_config, config)
    pending_records_config_by_id[config["id"]] = config
    pending_records_compare_config_by_id[config["id"]] = config_for_comparison(config)
  end

  local active_records_config_by_id = {}
  local active_records_compare_config_by_id = {}
  for _, config in ipairs(active_records_config) do
    active_records_config_by_id[config["id"]] = config
    active_records_compare_config_by_id[config["id"]] = config_for_comparison(config)
  end

  local changes = {
    new = {},
    modified = {},
    deleted = {},
    identical = {},
  }

  for _, active_record_config in ipairs(active_records_config) do
    local pending_record_config = pending_records_config_by_id[active_record_config["id"]]
    if not pending_record_config then
      if policy.is_authorized_show(current_admin, active_record_config, policy_permission_id) then
        table.insert(changes["deleted"], {
          mode = "deleted",
          active = active_record_config,
          pending = nil,
        })
      end
    end
  end

  for _, pending_record_config in ipairs(pending_records_config) do
    policy.authorize_show(current_admin, pending_record_config, policy_permission_id)

    local active_record_config = active_records_config_by_id[pending_record_config["id"]]

    if not active_record_config then
      table.insert(changes["new"], {
        mode = "new",
        active = nil,
        pending = pending_record_config,
      })
    else
      policy.authorize_show(current_admin, active_record_config, policy_permission_id)

      local active_record_compare_config = active_records_compare_config_by_id[pending_record_config["id"]]
      local pending_record_compare_config = pending_records_compare_config_by_id[pending_record_config["id"]]
      if deepcompare(active_record_compare_config, pending_record_compare_config) then
        table.insert(changes["identical"], {
          mode = "identical",
          active = active_record_config,
          pending = pending_record_config,
        })
      else
        table.insert(changes["modified"], {
          mode = "modified",
          active = active_record_config,
          pending = pending_record_config,
        })
      end
    end
  end

  for _, type_changes in pairs(changes) do
    for _, change in ipairs(type_changes) do
      if change["pending"] then
        change["id"] = json_null_default(change["pending"]["id"])
        change["name"] = json_null_default(change["pending"]["name"] or change["pending"]["frontend_host"])
      else
        change["id"] = json_null_default(change["active"]["id"])
        change["name"] = json_null_default(change["active"]["name"] or change["active"]["frontend_host"])
      end

      local active_record_compare_config = active_records_compare_config_by_id[change["id"]]
      local pending_record_compare_config = pending_records_compare_config_by_id[change["id"]]
      change["active_yaml"] = json_null_default(pretty_yaml_dump(active_record_compare_config))
      change["pending_yaml"] = json_null_default(pretty_yaml_dump(pending_record_compare_config))
    end

    setmetatable(type_changes, cjson.empty_array_mt)
  end

  return changes
end

PublishedConfig.pending_changes_json = function(current_admin)
  local active_config = PublishedConfig.active_config() or {}
  return {
    apis = model_pending_changes_json(active_config["apis"] or {}, ApiBackend, api_backend_policy, current_admin),
    website_backends = model_pending_changes_json(active_config["website_backends"] or {}, WebsiteBackend, website_backend_policy, current_admin),
  }
end

local function set_config_for_publishing(active_config, new_config, category, model, policy, publish_ids, current_admin)
  assert(active_config)
  assert(new_config)
  assert(category)
  assert(model)
  assert(policy)
  assert(publish_ids)
  assert(current_admin)

  if not new_config[category] then
    new_config[category] = {}
  end

  local changed = false
  local policy_permission_id = "backend_publish"

  local active_config_by_id = {}
  if active_config[category] then
    for _, data in ipairs(active_config[category]) do
      active_config_by_id[data["id"]] = data
    end
  end

  local new_config_by_id = {}
  for _, data in ipairs(new_config[category]) do
    new_config_by_id[data["id"]] = data
  end

  for _, record_id in ipairs(publish_ids) do
    local active_record_config = active_config_by_id[record_id]
    if active_record_config then
      policy.authorize_show(current_admin, active_record_config, policy_permission_id)
    end

    local record = model:find(record_id)
    if record then
      local new_record_config = record:as_json(as_json_options)
      policy.authorize_show(current_admin, new_record_config, policy_permission_id)
      new_config_by_id[record_id] = new_record_config
    else
      new_config_by_id[record_id] = nil
    end

    changed = true
  end

  new_config[category] = table_values(new_config_by_id)
  return changed
end

local function set_settings_publish_timestamp(api_backend_ids, mode_column, timestamp_column)
  local db_ids = db.list(api_backend_ids)

  db.query([[
    UPDATE api_backend_settings
    SET ]] .. db.escape_identifier(timestamp_column) .. [[ = transaction_timestamp()
    WHERE ]] .. db.escape_identifier(mode_column) .. [[ LIKE 'transition_%'
      AND ]] .. db.escape_identifier(timestamp_column) .. [[ IS NULL
      AND (
        api_backend_id IN ?
        OR api_backend_sub_url_settings_id IN (SELECT id FROM api_backend_sub_url_settings WHERE api_backend_id IN ?)
      )]], db_ids, db_ids)

  db.query([[
    UPDATE api_backend_settings
    SET ]] .. db.escape_identifier(timestamp_column) .. [[ = NULL
    WHERE (]] .. db.escape_identifier(mode_column) .. [[ IS NULL
        OR ]] .. db.escape_identifier(mode_column) .. [[ NOT LIKE 'transition_%'
      )
      AND (
        api_backend_id IN ?
        OR api_backend_sub_url_settings_id IN (SELECT id FROM api_backend_sub_url_settings WHERE api_backend_id IN ?)
      )]], db_ids, db_ids)
end

PublishedConfig.publish_ids = function(api_backend_ids, website_backend_ids, current_admin)
  local transaction_started = model_ext.start_transaction()
  local active_config = PublishedConfig.active_config() or {}
  local new_config = deepcopy(active_config)
  local published_config
  model_ext.try_save(function()
    if not is_empty(api_backend_ids) then
      set_settings_publish_timestamp(api_backend_ids, "require_https", "require_https_transition_start_at")
      set_settings_publish_timestamp(api_backend_ids, "api_key_verification_level", "api_key_verification_transition_start_at")
    end

    local apis_changed = set_config_for_publishing(active_config, new_config, "apis", ApiBackend, api_backend_policy, api_backend_ids, current_admin)
    local websites_changed = set_config_for_publishing(active_config, new_config, "website_backends", WebsiteBackend, website_backend_policy, website_backend_ids, current_admin)

    if apis_changed or websites_changed then
      table.sort(new_config["apis"], function(a, b)
        return a["created_order"] < b["created_order"]
      end)
      table.sort(new_config["website_backends"], function(a, b)
        return a["created_order"] < b["created_order"]
      end)

      local published = assert(PublishedConfig:create({
        config = new_config,
      }))
      published_config = published.config
    else
      published_config = active_config
    end
  end, transaction_started)
  model_ext.commit_transaction(transaction_started)

  return published_config
end

return PublishedConfig
