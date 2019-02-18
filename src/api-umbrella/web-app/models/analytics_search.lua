local AnalyticsSearchElasticsearch = require "api-umbrella.web-app.models.analytics_search_elasticsearch"

local _M = {}

function _M.factory(adapter)
  if adapter == "elasticsearch" then
    return AnalyticsSearchElasticsearch.new()
  end
end

return _M
