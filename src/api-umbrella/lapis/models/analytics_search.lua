local AnalyticsSearchElasticsearch = require "api-umbrella.lapis.models.analytics_search_elasticsearch"

local _M = {}

function _M.factory(adapter, options)
  if adapter == "elasticsearch" then
    return AnalyticsSearchElasticsearch.new(options)
  end
end

return _M
