local AnalyticsSearchElasticsearch = require "api-umbrella.lapis.models.analytics_search_elasticsearch"
local time = require "posix.time"

local _M = {}

function _M.factory(adapter, options)
  if options and options["end_time"] then
    local end_time = time.strptime(options["end_time"], "%Y-%m-%d")
    ngx.log(ngx.ERR, "END_TIME: " .. inspect(end_time))
    end_time.tm_sec = 59
    end_time.tm_min = 59
    end_time.tm_hour = 23

    options["end_time"] = time.strftime("%FT%T", end_time)
  end

  if adapter == "elasticsearch" then
    return AnalyticsSearchElasticsearch.new(options)
  end
end

return _M
