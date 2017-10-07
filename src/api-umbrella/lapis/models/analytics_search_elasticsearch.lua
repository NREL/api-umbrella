local cjson = require "cjson"
local escape_regex = require "api-umbrella.utils.escape_regex"
local http = require "resty.http"
local is_empty = require("pl.types").is_empty

local _M = {}
_M.__index = _M

function _M.new(options)
  local self = {
    start_time = assert(options["start_time"]),
    end_time = assert(options["end_time"]),
    interval = assert(options["interval"]),
    elasticsearch_host = config["elasticsearch"]["hosts"][1],
    query = {
      query = {
        filtered = {
          query = {
            match_all = {},
          },
          filter = {
            bool = {
              must = {},
              must_not = {},
            },
          },
        },
      },
      sort = {
        { request_at = "desc" },
      },
      aggregations = {},
      size = 0,
      timeout = 90,
    },
  }

  return setmetatable(self, _M)
end

function _M:set_permission_scope(scopes)
end

function _M:filter_by_time_range()
  table.insert(self.query["query"]["filtered"]["filter"]["bool"]["must"], {
    range = {
      request_at = {
        from = self.start_time,
        to = self.end_time,
      },
    },
  })
end

function _M:set_interval(start_time, end_time)
end

function _M:set_search_query_string(query_string)
  if not is_empty(query_string) then
    self.query["query"]["filtered"]["query"] = {
      query_string = {
        query = query_string,
      },
    }
  end
end

function _M:set_search_filters(query_string)
end

function _M:aggregate_by_drilldown(prefix, size)
  if not size then
    size = 0
  end

  self.query["aggregations"]["drilldown"] = {
    terms = {
      field = "request_hierarchy",
      size = size,
      include = escape_regex(prefix) .. ".*",
    },
  }
end

function _M:aggregate_by_drilldown_over_time(prefix)
  table.insert(self.query["query"]["filtered"]["filter"]["bool"]["must"], {
    prefix = {
      request_hierarchy = prefix,
    },
  })

  self.query["aggregations"]["top_path_hits_over_time"] = {
    terms = {
      field = "request_hierarchy",
      size = 10,
      include = escape_regex(prefix) .. ".*",
    },
    aggregations = {
      drilldown_over_time = {
        date_histogram = {
          field = "request_at",
          interval = self.interval,
          time_zone = "America/New_York", -- Time.zone.name,
          min_doc_count = 0,
          extended_bounds = {
            min = self.start_time,
            max = self.end_time,
          },
        },
      },
    },
  }

  self.query["aggregations"]["hits_over_time"] = {
    date_histogram = {
      field = "request_at",
      interval = self.interval,
      time_zone = "America/New_York", -- Time.zone.name,
      min_doc_count = 0,
      extended_bounds = {
        min = self.start_time,
        max = self.end_time,
      },
    },
  }

  if config["elasticsearch"]["api_version"] < 2 then
    self.query["aggregations"]["top_path_hits_over_time"]["aggregations"]["drilldown_over_time"]["date_histogram"]["pre_zone_adjust_large_interval"] = true
    self.query["aggregations"]["hits_over_time"]["date_histogram"]["pre_zone_adjust_large_interval"] = true
  end
end

function _M:fetch_results()
  setmetatable(self.query["query"]["filtered"]["filter"]["bool"]["must_not"], cjson.empty_array_mt)
  setmetatable(self.query["query"]["filtered"]["filter"]["bool"]["must"], cjson.empty_array_mt)
  setmetatable(self.query["sort"], cjson.empty_array_mt)

  ngx.log(ngx.ERR, "FETCH: " .. inspect(self))

  local httpc = http.new()
  local res, err = httpc:request_uri(self.elasticsearch_host .. "/_search", {
    method = "POST",
    headers = {
      ["Content-Type"] = "application/json",
    },
    body = cjson.encode(self.query),
  })
  local data = cjson.decode(res.body)
  ngx.log(ngx.ERR, "FETCH: " .. inspect(res.body))
  ngx.log(ngx.ERR, "FETCH: " .. inspect(data))

  return data
end

return _M
