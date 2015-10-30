local mongo = require "api-umbrella.utils.mongo"
local nillify_json_nulls = require "api-umbrella.utils.nillify_json_nulls"

local _M = {}

function _M.fetch(last_fetched_version)
  local raw_result, err = mongo.first("config_versions", {
    sort = "-version",
    query = {
      version = {
        ["$gt"] = {
          ["$date"] = last_fetched_version,
        },
      },
    },
  })

  if err then
    return nil, err
  else
    local result = {}
    if raw_result then
      if raw_result["config"] then
        nillify_json_nulls(raw_result["config"])

        if raw_result["config"]["apis"] then
          result["apis"] = raw_result["config"]["apis"]
        end

        if raw_result["config"]["website_backends"] then
          result["website_backends"] = raw_result["config"]["website_backends"]
        end
      end

      if raw_result["version"] then
        result["version"] = raw_result["version"]["$date"]
      end
    end

    return result
  end
end

return _M
