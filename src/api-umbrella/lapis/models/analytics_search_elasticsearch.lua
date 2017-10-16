local cjson = require "cjson"
local escape_regex = require "api-umbrella.utils.escape_regex"
local http = require "resty.http"
local is_empty = require("pl.types").is_empty
local startswith = require("pl.stringx").startswith

CASE_SENSITIVE_FIELDS = {
  api_key = 1,
  request_ip_city = 1,
}

UPPERCASE_FIELDS = {
  request_method = 1,
  request_ip_country = 1,
  request_ip_region = 1,
}

local _M = {}
_M.__index = _M

local function parse_query_builder(query)
  local query_filter
  if not is_empty(query) then
    local filters = {}
    for _, rule in ipairs(query["rules"]) do
      local filter
      local operator = rule["operator"]
      local field = rule["field"]
      local value = rule["value"]

      if CASE_SENSITIVE_FIELDS[field] and type(value) == "string" then
        if UPPERCASE_FIELDS[field] then
          value = string.upper(value)
        else
          value = string.lower(value)
        end
      end

      if operator == "equal" or operator == "not_equal" then
        filter = {
          term = {
            [field] = value,
          },
        }
      elseif operator == "not_equal" then
        filter = {
          term = {
            [field] = value,
          },
        }
      elseif operator == "begins_with" or operator == "not_begins_with" then
        filter = {
          prefix = {
            [field] = value,
          },
        }
      elseif operator == "contains" or operator == "not_contains" then
        filter = {
          regexp = {
            [field] = ".*" .. escape_regex(value) .. ".*",
          },
        }
      elseif operator == "is_null" or operator == "is_not_null" then
        filter = {
          exists = {
            field = field,
          },
        }
      elseif operator == "less" then
        filter = {
          range = {
            [field] = {
              lt = tonumber(value),
            },
          },
        }
      elseif operator == "less_or_equal" then
        filter = {
          range = {
            [field] = {
              lte = tonumber(value),
            },
          },
        }
      elseif operator == "greater" then
        filter = {
          range = {
            [field] = {
              gt = tonumber(value),
            },
          },
        }
      elseif operator == "greater_or_equal" then
        filter = {
          range = {
            [field] = {
              gte = tonumber(value),
            },
          },
        }
      elseif operator == "between" then
        filter = {
          range = {
            [field] = {
              gte = tonumber(value[1]),
              lte = tonumber(value[2]),
            },
          },
        }
      else
        error("unknown filter operator: " .. inspect(operator) .. "  (rule: " .. inspect(rule) .. ")")
      end

      if operator == "is_null" or startswith(operator, "not_") then
        filter = {
          bool = {
            must_not = filter,
          }
        }
      end

      table.insert(filters, filter)
    end

    if not is_empty(filters) then
      local condition
      if query["condition"] == "OR" then
        condition = "should"
      else
        condition = "must"
      end

      query_filter = {
        bool = {
          [condition] = filters,
        },
      }
    end
  end

  return query_filter
end

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
  local filter = parse_query_builder(scopes)
  table.insert(self.query["query"]["filtered"]["filter"]["bool"]["must"], filter)
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

function _M:set_search_filters(query)
  if type(query) == "string" and query ~= "" then
    query = cjson.decode(query)
  end

  local filter = parse_query_builder(query)
  if filter then
    table.insert(self.query["query"]["filtered"]["filter"]["bool"]["must"], filter)
  end
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
          time_zone = config["analytics"]["timezone"], -- "America/New_York", -- Time.zone.name,
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
      time_zone = config["analytics"]["timezone"], -- "America/New_York", -- Time.zone.name,
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
