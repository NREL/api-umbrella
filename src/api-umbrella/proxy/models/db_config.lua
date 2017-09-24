local nillify_json_nulls = require "api-umbrella.utils.nillify_json_nulls"
local pg_utils = require "api-umbrella.utils.pg_utils"

local _M = {}

function _M.fetch(last_fetched_version)
  local raw_result, err = pg_utils.query("SELECT * FROM published_config WHERE id > " .. pg_utils.escape_literal(last_fetched_version) .. " ORDER BY id DESC LIMIT 1")
  if not raw_result then
    return nil, err
  end

  local result = {}
  local raw_config = raw_result[1]
  if raw_config then
    if raw_config["config"] then
      nillify_json_nulls(raw_config["config"])

      if raw_config["config"]["apis"] then
        result["apis"] = raw_config["config"]["apis"]
      end

      if raw_config["config"]["website_backends"] then
        result["website_backends"] = raw_config["config"]["website_backends"]
      end
    end

    result["version"] = raw_config["id"]
  end

  return result
end

return _M
