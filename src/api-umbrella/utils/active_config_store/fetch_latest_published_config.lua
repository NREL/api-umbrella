local nillify_json_nulls = require "api-umbrella.utils.nillify_json_nulls"
local query = require("api-umbrella.utils.pg_utils").query

return function(last_fetched_version)
  local select_sql = {}
  local select_values = {}
  table.insert(select_sql, "SELECT id, config FROM published_config")
  if last_fetched_version then
    table.insert(select_sql, "WHERE id > :id")
    select_values["id"] = last_fetched_version
  end
  table.insert(select_sql, "ORDER BY id DESC LIMIT 1")
  select_sql = table.concat(select_sql, " ")

  local result, err = query(select_sql, select_values, { quiet = true })
  if not result then
    return nil, err
  end

  local published_config = result[1]

  if published_config and published_config["config"] then
    nillify_json_nulls(published_config["config"])
  end

  return published_config
end
