local cjson = require("cjson")
local db = require "lapis.db"
local deepcompare = require("pl.tablex").deepcompare
local is_array = require "api-umbrella.utils.is_array"
local is_hash = require "api-umbrella.utils.is_hash"
local model_ext = require "api-umbrella.utils.model_ext"
local pg_encode_json = require("pgmoon.json").encode_json
local pretty_yaml_dump = require "api-umbrella.utils.pretty_yaml_dump"

local db_null = db.NULL
local db_raw = db.raw
local json_null = cjson.null

local PublishedConfig = model_ext.new_class("published_config", {
  as_json = function()
    return {}
  end,
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

PublishedConfig.active_config = function()
  local published = PublishedConfig:select("ORDER BY id DESC LIMIT 1")[1]
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
  creator = 1,
  id = 1,
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
      if not compare_exclude_keys[key] and not ngx.re.match(key, "_ids?$", "jo") then
        compare_object[key] = config_for_comparison(value)
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

PublishedConfig.pending_changes_json = function(active_records_config, model, policy, current_admin)
  assert(active_records_config)
  assert(model)
  assert(policy)
  assert(current_admin)

  local where = policy.authorized_query_scope(current_admin, "backend_publish")

  local pending_records_config = {}
  local pending_records_config_by_id = {}
  local pending_records_compare_config_by_id = {}
  local pending_records = model.all_sorted(where)
  for _, record in ipairs(pending_records) do
    local config = record:as_json()
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
      table.insert(changes["deleted"], {
        mode = "deleted",
        active = active_record_config,
        pending = nil,
      })
    end
  end

  for _, pending_record_config in ipairs(pending_records_config) do
    local active_record_config = active_records_config_by_id[pending_record_config["id"]]
    if not active_record_config then
      table.insert(changes["new"], {
        mode = "new",
        active = nil,
        pending = pending_record_config,
      })
    else
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
        change["id"] = change["pending"]["id"] or json_null
        change["name"] = change["pending"]["name"] or change["pending"]["frontend_host"] or json_null
      else
        change["id"] = change["active"]["id"] or json_null
        change["name"] = change["active"]["name"] or change["active"]["frontend_host"] or json_null
      end

      local active_record_compare_config = active_records_compare_config_by_id[change["id"]]
      local pending_record_compare_config = pending_records_compare_config_by_id[change["id"]]
      change["active_yaml"] = pretty_yaml_dump(active_record_compare_config) or json_null
      change["pending_yaml"] = pretty_yaml_dump(pending_record_compare_config) or json_null
    end

    setmetatable(type_changes, cjson.empty_array_mt)
  end

  return changes
end

return PublishedConfig
