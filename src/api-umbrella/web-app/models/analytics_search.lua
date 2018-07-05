local AnalyticsSearchElasticsearch = require "api-umbrella.web-app.models.analytics_search_elasticsearch"
local config = require "api-umbrella.proxy.models.file_config"
local icu_date = require "icu-date"

local date = icu_date.new({
  zone_id = config["analytics"]["timezone"],
})
local fields = icu_date.fields
local format_date = icu_date.formats.pattern("yyyy-MM-dd")
local format_iso8601 = icu_date.formats.iso8601()

local _M = {}

function _M.factory(adapter, options)
  if options and options["start_time"] then
    date:parse(format_date, options["start_time"])
    options["start_time"] = date:format(format_iso8601)
  end

  if options and options["end_time"] then
    date:parse(format_date, options["end_time"])
    date:set(fields.HOUR_OF_DAY, 23)
    date:set(fields.MINUTE, 59)
    date:set(fields.SECOND, 59)
    date:set(fields.MILLISECOND, 999)
    options["end_time"] = date:format(format_iso8601)
  end

  if adapter == "elasticsearch" then
    return AnalyticsSearchElasticsearch.new(options)
  end
end

return _M
