local AnalyticsSearchOpensearch = require "api-umbrella.web-app.models.analytics_search_opensearch"

local _M = {}

function _M.factory(adapter)
  if adapter == "opensearch" then
    return AnalyticsSearchOpensearch.new()
  end
end

return _M
