local AnalyticsCache = require "api-umbrella.web-app.models.analytics_cache"
local add_error = require("api-umbrella.web-app.utils.model_ext").add_error
local cjson = require "cjson.safe"
local config = require("api-umbrella.utils.load_config")()
local deepcopy = require("pl.tablex").deepcopy
local elasticsearch = require "api-umbrella.utils.elasticsearch"
local escape_regex = require "api-umbrella.utils.escape_regex"
local icu_date = require "icu-date-ffi"
local is_empty = require "api-umbrella.utils.is_empty"
local json_encode = require "api-umbrella.utils.json_encode"
local path_join = require "api-umbrella.utils.path_join"
local re_split = require("ngx.re").split
local startswith = require("pl.stringx").startswith
local t = require("api-umbrella.web-app.utils.gettext").gettext
local validation_ext = require "api-umbrella.web-app.utils.validation_ext"
local xpcall_error_handler = require "api-umbrella.utils.xpcall_error_handler"

local elasticsearch_query = elasticsearch.query

local date_utc = icu_date.new({
  zone_id = "UTC"
})
local date_tz = icu_date.new({
  zone_id = config["analytics"]["timezone"],
})
local format_date = icu_date.formats.pattern("yyyy-MM-dd")
local format_iso8601 = icu_date.formats.iso8601()

local CASE_SENSITIVE_FIELDS = {
  api_key = 1,
  request_ip_city = 1,
}

local UPPERCASE_FIELDS = {
  request_ip_country = 1,
  request_ip_region = 1,
}

local _M = {}
_M.__index = _M

local function index_names(start_time, end_time)
  assert(start_time)
  assert(end_time)

  date_utc:parse(format_iso8601, end_time)
  -- TODO: For some reason, set_time_zone_id doesn't work properly if format()
  -- isn't called first, when changing between time zones. Need to debug why
  -- this isn't working as expected with icu-date, but in the meantime, this
  -- workaround seems to make set_time_zone_id work as expected.
  --
  -- The following test can reproduce this problem (it will break without this
  -- format() call):
  -- env ELASTICSEARCH_TEST_API_VERSION=5 ELASTICSEARCH_TEST_TEMPLATE_VERSION=2 ELASTICSEARCH_TEST_INDEX_PARTITION=daily bundle exec minitest test/apis/admin/stats/test_search.rb -n test_bins_results_by_day_with_time_zone_support
  date_utc:format(format_iso8601)
  date_utc:set_time_zone_id("UTC")
  local end_time_millis = date_utc:get_millis()

  date_utc:parse(format_iso8601, start_time)
  -- TODO: See above about why this format() call is here, but shouldn't be
  -- necessary.
  date_utc:format(format_iso8601)
  date_utc:set_time_zone_id("UTC")
  if config["elasticsearch"]["index_partition"] == "monthly" then
    date_utc:set(icu_date.fields.DAY_OF_MONTH, 1)
  end
  date_utc:set(icu_date.fields.HOUR_OF_DAY, 0)
  date_utc:set(icu_date.fields.MINUTE, 0)
  date_utc:set(icu_date.fields.SECOND, 0)
  date_utc:set(icu_date.fields.MILLISECOND, 0)

  local names = {}
  while date_utc:get_millis() <= end_time_millis do
    table.insert(names, config["elasticsearch"]["index_name_prefix"] .. "-logs-" .. date_utc:format(elasticsearch.partition_date_format))
    if config["elasticsearch"]["index_partition"] == "monthly" then
      date_utc:add(icu_date.fields.MONTH, 1)
    elseif config["elasticsearch"]["index_partition"] == "daily" then
      date_utc:add(icu_date.fields.DATE, 1)
    end
  end

  return names
end

local function parse_query_builder(query)
  local query_filter
  if not is_empty(query) then
    local filters = {}
    for _, rule in ipairs(query["rules"]) do
      local filter
      local operator = rule["operator"]
      local field = rule["field"]
      local value = rule["value"]

      local es_field = field
      if field == "request_id" then
        es_field = "_id"
      end

      if not CASE_SENSITIVE_FIELDS[field] and type(value) == "string" then
        if UPPERCASE_FIELDS[field] then
          value = string.upper(value)
        else
          value = string.lower(value)
        end
      end

      if operator == "equal" or operator == "not_equal" then
        filter = {
          term = {
            [es_field] = value,
          },
        }
      elseif operator == "begins_with" or operator == "not_begins_with" then
        filter = {
          prefix = {
            [es_field] = value,
          },
        }
      elseif operator == "contains" or operator == "not_contains" then
        filter = {
          regexp = {
            [es_field] = ".*" .. escape_regex(value) .. ".*",
          },
        }
      elseif operator == "is_null" or operator == "is_not_null" then
        filter = {
          exists = {
            field = es_field,
          },
        }
      elseif operator == "less" then
        filter = {
          range = {
            [es_field] = {
              lt = tonumber(value),
            },
          },
        }
      elseif operator == "less_or_equal" then
        filter = {
          range = {
            [es_field] = {
              lte = tonumber(value),
            },
          },
        }
      elseif operator == "greater" then
        filter = {
          range = {
            [es_field] = {
              gt = tonumber(value),
            },
          },
        }
      elseif operator == "greater_or_equal" then
        filter = {
          range = {
            [es_field] = {
              gte = tonumber(value),
            },
          },
        }
      elseif operator == "between" then
        filter = {
          range = {
            [es_field] = {
              gte = tonumber(value[1]),
              lte = tonumber(value[2]),
            },
          },
        }
      else
        error("unknown filter operator: " .. (operator or "") .. "  (field: " .. (field or "") .. "; value: " .. (value or "") .. ")")
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

function _M.new()
  local self = {
    errors = {},
    query = {
      ignore_unavailable = "true",
      allow_no_indices = "true",
    },
    body = {
      query = {
        bool = {
          must = {
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
      timeout = "90s",
    },
  }

  if config["elasticsearch"]["api_version"] >= 7 then
    self.body["track_total_hits"] = true
  end

  return setmetatable(self, _M)
end

function _M:set_sort(order_fields)
  if not is_empty(order_fields) then
    self.body["sort"] = {}
    for _, order_field in ipairs(order_fields) do
      local column_name = order_field[1]
      local dir = order_field[2]
      if not is_empty(column_name) and not is_empty(dir) then
        table.insert(self.body["sort"], { [column_name] = string.lower(dir) })
      end
    end
  end
end

function _M:set_start_time(start_time)
  local ok = xpcall(date_tz.parse, xpcall_error_handler, date_tz, format_date, start_time)
  if not ok then
    add_error(self.errors, "start_at", "start_at", t("is not valid date"))
    return false
  end

  self.start_time = date_tz:format(format_iso8601)

  if self.body["aggregations"]["hits_over_time"] then
    self.body["aggregations"]["hits_over_time"]["date_histogram"]["extended_bounds"]["min"] = self.start_time
  end
end

function _M:set_end_time(end_time)
  local ok = xpcall(date_tz.parse, xpcall_error_handler, date_tz, format_date, end_time)
  if not ok then
    add_error(self.errors, "end_at", "end_at", t("is not valid date"))
    return false
  end

  date_tz:set(icu_date.fields.HOUR_OF_DAY, 23)
  date_tz:set(icu_date.fields.MINUTE, 59)
  date_tz:set(icu_date.fields.SECOND, 59)
  date_tz:set(icu_date.fields.MILLISECOND, 999)

  self.end_time = date_tz:format(format_iso8601)

  if self.body["aggregations"]["hits_over_time"] then
    self.body["aggregations"]["hits_over_time"]["date_histogram"]["extended_bounds"]["max"] = self.end_time
  end
end

function _M:set_interval(interval)
  self.interval = interval
end

function _M:set_permission_scope(scopes)
  if scopes and scopes["rules"] then
    local filter = {
      bool = {
        should = {},
      },
    }

    if not is_empty(scopes["rules"]) then
      for _, rule in ipairs(scopes["rules"]) do
        table.insert(filter["bool"]["should"], parse_query_builder(rule))
      end

      table.insert(self.body["query"]["bool"]["filter"]["bool"]["must"], filter)
    end
  elseif scopes then
    table.insert(self.body["query"]["bool"]["filter"]["bool"]["must"], scopes)
  end
end

function _M:filter_exclude_imported()
  table.insert(self.body["query"]["bool"]["filter"]["bool"]["must_not"], {
    exists = {
      field = "imported",
    },
  })
end

function _M:set_search_query_string(query_string)
  if not is_empty(query_string) then
    table.insert(self.body["query"]["bool"]["filter"]["bool"]["must"], {
      query_string = {
        query = query_string,
      },
    })
  end
end

function _M:set_search_filters(query)
  if type(query) == "string" and query ~= "" then
    local err
    query, err = cjson.decode(query)
    if err then
      add_error(self.errors, "query", "query", t("is not valid JSON"))
      return false
    end
  end

  if not is_empty(query) then
    if type(query) ~= "table" or type(query["rules"]) ~= "table" then
      add_error(self.errors, "query", "query", t("wrong format"))
      return false
    end
  end

  local filter = parse_query_builder(query)
  if filter then
    table.insert(self.body["query"]["bool"]["filter"]["bool"]["must"], filter)
  end
end

function _M:set_offset(offset)
  local ok = validation_ext.optional.tonumber.number(offset)
  if not ok then
    add_error(self.errors, "start", "start", t("is not a number"))
    return false
  end

  self.body["from"] = tonumber(offset) or 0
end

function _M:set_limit(limit)
  local ok = validation_ext.optional.tonumber.number(limit)
  if not ok then
    add_error(self.errors, "length", "length", t("is not a number"))
    return false
  end

  self.body["size"] = tonumber(limit) or 0
end

function _M:set_timeout(timeout)
  self.body["timeout"] = timeout .. "s"
end

function _M:aggregate_by_interval()
  self.body["aggregations"]["hits_over_time"] = {
    date_histogram = {
      field = "request_at",
      interval = self.interval,
      time_zone = config["analytics"]["timezone"],
      min_doc_count = 0,
      extended_bounds = {
        min = self.start_time,
        max = self.end_time,
      },
    },
  }

  if config["elasticsearch"]["api_version"] < 2 then
    self.body["aggregations"]["hits_over_time"]["date_histogram"]["pre_zone_adjust_large_interval"] = true
  end
end

function _M:aggregate_by_interval_for_summary()
  self:aggregate_by_interval()

  self.body["aggregations"]["hits_over_time"]["aggregations"] = {
    unique_user_ids = {
      terms = {
        field = "user_id",
        size = 100000000,
        shard_size = 100000000 * 4,
      },
    },
    response_time_average = {
      avg = {
        field = "response_time",
      },
    },
  }
end

function _M:aggregate_by_term(field, size)
  self.body["aggregations"]["top_" .. field] = {
    terms = {
      field = field,
      size = size,
      shard_size = size * 4,
    },
  }

  self.body["aggregations"]["value_count_" .. field] = {
    value_count = {
      field = field,
    },
  }

  self.body["aggregations"]["missing_" .. field] = {
    missing = {
      field = field,
    },
  }
end

function _M:aggregate_by_cardinality(field)
  self.body["aggregations"]["unique_" .. field] = {
    cardinality = {
      field = field,
      precision_threshold = 100,
    },
  }
end

function _M:aggregate_by_users(size)
  self:aggregate_by_term("user_email", size)
  self:aggregate_by_cardinality("user_email")
end

function _M:aggregate_by_request_ip(size)
  self:aggregate_by_term("request_ip", size)
  self:aggregate_by_cardinality("request_ip")
end

function _M:aggregate_by_response_time_average()
  self.body["aggregations"]["response_time_average"] = {
    avg = {
      field = "response_time",
    },
  }
end

function _M:aggregate_by_drilldown(prefix, size)
  local prefix_parts = re_split(prefix, "/", "jo")
  self.drilldown_prefix = prefix
  self.drilldown_depth = tonumber(prefix_parts[1])
  self.drilldown_parent = {}
  self.drilldown_path_segments = {}

  local ok = validation_ext.string:minlen(1)(self.drilldown_prefix)
  if not ok then
    add_error(self.errors, "prefix", "prefix", t("can't be blank"))
    return false
  end

  ok = validation_ext.tonumber.number(self.drilldown_depth)
  if not ok then
    add_error(self.errors, "prefix", "prefix", t("wrong format"))
    return false
  end

  ok = validation_ext.optional.tonumber.number(size)
  if not ok then
    add_error(self.errors, "size", "size", t("is not a number"))
    return false
  end

  for index, value in ipairs(prefix_parts) do
    if index > 1 then
      table.insert(self.drilldown_path_segments, {
        level = index - 2,
        value = value,
      })

      if index <= self.drilldown_depth + 1 then
        table.insert(self.drilldown_parent, value)
      end
    end
  end
  self.drilldown_parent = path_join(self.drilldown_parent)
  if self.drilldown_parent == "" then
    self.drilldown_parent = nil
  end

  if not size then
    size = 100000000
  end

  self.body["aggregations"]["drilldown"] = {
    terms = {
      size = tonumber(size),
    },
  }

  if config["elasticsearch"]["template_version"] < 2 then
    table.insert(self.body["query"]["bool"]["filter"]["bool"]["must"], {
      prefix = {
        request_hierarchy = self.drilldown_prefix,
      },
    })

    self.body["aggregations"]["drilldown"]["terms"]["field"] = "request_hierarchy"
    self.body["aggregations"]["drilldown"]["terms"]["include"] = escape_regex(prefix) .. ".*"
  else
    for _, segment in ipairs(self.drilldown_path_segments) do
      table.insert(self.body["query"]["bool"]["filter"]["bool"]["must"], {
        term = {
          ["request_url_hierarchy_level" .. segment["level"]] = segment["value"] .. "/",
        },
      })
    end

    self.body["aggregations"]["drilldown"]["terms"]["field"] = "request_url_hierarchy_level" .. self.drilldown_depth
  end
end

function _M:aggregate_by_drilldown_over_time()
  if not is_empty(self.errors) then
    return false
  end

  -- We assume aggregate_by_drilldown has been called first, to parse and set
  -- some of the internal drilldown variables.
  assert(self.drilldown_prefix)
  assert(self.drilldown_depth)

  self.body["aggregations"]["top_path_hits_over_time"] = {
    terms = {
      size = 10,
    },
    aggregations = {
      drilldown_over_time = {
        date_histogram = {
          field = "request_at",
          interval = self.interval,
          time_zone = config["analytics"]["timezone"],
          min_doc_count = 0,
          extended_bounds = {
            min = self.start_time,
            max = self.end_time,
          },
        },
      },
    },
  }

  if config["elasticsearch"]["template_version"] < 2 then
    self.body["aggregations"]["top_path_hits_over_time"]["terms"]["field"] = "request_hierarchy"
    self.body["aggregations"]["top_path_hits_over_time"]["terms"]["include"] = escape_regex(self.drilldown_prefix) .. ".*"
  else
    self.body["aggregations"]["top_path_hits_over_time"]["terms"]["field"] = "request_url_hierarchy_level" .. self.drilldown_depth
  end

  self.body["aggregations"]["hits_over_time"] = {
    date_histogram = {
      field = "request_at",
      interval = self.interval,
      time_zone = config["analytics"]["timezone"],
      min_doc_count = 0,
      extended_bounds = {
        min = self.start_time,
        max = self.end_time,
      },
    },
  }

  if config["elasticsearch"]["api_version"] < 2 then
    self.body["aggregations"]["top_path_hits_over_time"]["aggregations"]["drilldown_over_time"]["date_histogram"]["pre_zone_adjust_large_interval"] = true
    self.body["aggregations"]["hits_over_time"]["date_histogram"]["pre_zone_adjust_large_interval"] = true
  end
end

function _M:aggregate_by_user_stats(order)
  self.body["aggregations"]["user_stats"] = {
    terms = {
      field = "user_id",
      size = 100000000,
    },
    aggregations = {
      last_request_at = {
        max = {
          field = "request_at",
        },
      },
    },
  }

  if order then
    self.body["aggregations"]["user_stats"]["terms"]["order"] = order
  end
end

function _M:aggregate_by_ip_region_field(field)
  self.body["aggregations"]["regions"] = {
    terms = {
      field = field,
      size = 500,
    },
  }

  self.body["aggregations"]["missing_regions"] = {
    missing = {
      field = field,
    },
  }
end

function _M:filter_by_ip_country(country)
  table.insert(self.body["query"]["bool"]["filter"]["bool"]["must"], {
    term = {
      request_ip_country = country,
    }
  })
end

function _M:filter_by_ip_region(region)
  table.insert(self.body["query"]["bool"]["filter"]["bool"]["must"], {
    term = {
      request_ip_region = region,
    }
  })
end

function _M:query_header()
  local header = deepcopy(self.query)
  header["index"] = table.concat(index_names(self.start_time, self.end_time), ",")

  return header
end

function _M:query_body()
  local body = deepcopy(self.body)

  table.insert(body["query"]["bool"]["filter"]["bool"]["must"], {
    range = {
      request_at = {
        from = assert(self.start_time),
        to = assert(self.end_time),
      },
    },
  })

  setmetatable(body["query"]["bool"]["filter"]["bool"]["must_not"], cjson.empty_array_mt)
  setmetatable(body["query"]["bool"]["filter"]["bool"]["must"], cjson.empty_array_mt)
  if body["sort"] then
    setmetatable(body["sort"], cjson.empty_array_mt)
  end

  if is_empty(body["aggregations"]) then
    body["aggregations"] = nil
  end

  return body
end

function _M:fetch_results(options)
  if not is_empty(self.errors) then
    return coroutine.yield("error", self.errors)
  end

  local header
  if options and options["override_header"] then
    header = options["override_header"]
  else
    header = self:query_header()
  end

  local body
  if options and options["override_body"] then
    body = options["override_body"]
  else
    body = self:query_body()
  end

  -- When querying many indices (particularly if partitioning by day), we can
  -- run into URL length limits with the default search approach, which
  -- requires the indices be in the URL:
  -- https://github.com/elastic/elasticsearch/issues/26360
  --
  -- To sidestep this, we will perform most queries using the _msearch API,
  -- which allows us to put the index names in the POST body, so it's not
  -- subject to URL length limits.
  --
  -- However, for scroll queries, the msearch API doesn't support this
  -- (https://github.com/elastic/elasticsearch-php/issues/478#issuecomment-254321873),
  -- so we must revert back to normal search mode for these queries. In the
  -- event the URL length is too long, then we handle these scroll queries by
  -- querying all indices using a wildcard. While slightly less efficient, this
  -- should be better optimized in Elasticsearch 5+
  -- (https://www.elastic.co/blog/instant-aggregations-rewriting-queries-for-fun-and-profit).
  local body_json
  local err
  if self.query["scroll"] then
    -- The default URL length limit for Elasticsearch is 4096 bytes, but reduce
    -- the limit before truncating to the wildcard index name so there's still
    -- room for other query params.
    if string.len(header["index"]) > 3700 then
      header["index"] = config["elasticsearch"]["index_name_prefix"] .. "-logs-*"
    end

    local res
    res, err = elasticsearch_query("/" .. header["index"] .. "/_search", {
      method = "POST",
      query = self.query,
      body = body,
    })
    if not err and res and res.body_json then
      body_json = res.body_json
    end
  else
    local res
    res, err = elasticsearch_query("/_msearch", {
      method = "POST",
      headers = {
        ["Content-Type"] = "application/x-ndjson",
      },
      body = json_encode(header) .. "\n" .. json_encode(body) .. "\n",
    })

    if not err and res and res.body_json and res.body_json["responses"] and res.body_json["responses"][1] then
      body_json = res.body_json["responses"][1]
      if (body_json["_shards"] and not is_empty(body_json["_shards"]["failures"])) or (body_json["error"] and body_json["error"]["root_cause"]) then
        err = "Unsuccessful response: " .. (res.body or "")
      end
    end
  end

  if err or not body_json then
    ngx.log(ngx.ERR, "failed to query elasticsearch: ", err)
    ngx.ctx.error_status = 500
    return coroutine.yield("error", {
      _render = {
        errors = {
          {
            code = "UNEXPECTED_ERROR",
            message = t("An unexpected error occurred"),
          },
        },
      },
    })
  end

  if body_json and body_json["hits"] and body_json["hits"]["total"] then
    if config["elasticsearch"]["api_version"] >= 7 then
      body_json["hits"]["_total_value"] = body_json["hits"]["total"]["value"]
    else
      body_json["hits"]["_total_value"] = body_json["hits"]["total"]
    end
  end

  return body_json
end

function _M:fetch_results_bulk(callback)
  self.query["scroll"] = "10m"

  self.body["sort"] = { "_doc" }
  if config["elasticsearch"]["api_version"] < 2 then
    self.body["sort"] = nil
    self.query["search_type"] = "scan"
  end

  local raw_results = self:fetch_results()
  callback(raw_results["hits"]["hits"])

  local scroll_id
  while true do
    scroll_id = raw_results["_scroll_id"]
    local res, err = elasticsearch_query("/_search/scroll", {
      method = "GET",
      body = {
        scroll = self.query["scroll"],
        scroll_id = scroll_id,
      },
    })
    if err then
      ngx.log(ngx.ERR, "failed to query elasticsearch: ", err)
      ngx.ctx.error_status = 500
      return coroutine.yield("error", {
        _render = {
          errors = {
            {
              code = "UNEXPECTED_ERROR",
              message = t("An unexpected error occurred"),
            },
          },
        },
      })
    end

    raw_results = res.body_json
    if not raw_results["hits"] or is_empty(raw_results["hits"]["hits"]) then
      break
    end

    callback(raw_results["hits"]["hits"])
  end

  local _, err = elasticsearch_query("/_search/scroll", {
    method = "DELETE",
    body = {
      scroll_id = { scroll_id },
    },
  })
  if err then
    ngx.log(ngx.ERR, "elasticsearch scroll clear failed: ", err)
  end
end

local function cache_interval_results_process_batch(self, cache_ids, batch)
  local id_datas = {}
  for _, elem in ipairs(batch) do
    table.insert(id_datas, elem["cache_id_data"])
  end

  local update_expires_at_ids = {}

  local exists = AnalyticsCache:id_datas_exists(id_datas)
  for _, exist in ipairs(exists) do
    local batch_elem = batch[exist["array_index"]]
    local id_data = batch_elem["cache_id_data"]
    local expires_at = batch_elem["expires_at"]

    if not exist["cache_exists"] then
      -- Perform the real Elasticsearch query for uncached queries and cache
      -- the result.
      local results = self:fetch_results({
        override_header = id_data["header"],
        override_body = id_data["body"],
      })
      AnalyticsCache:upsert(id_data, results, expires_at)
    else
      if not update_expires_at_ids[expires_at] then
        update_expires_at_ids[expires_at] = {}
      end

      table.insert(update_expires_at_ids[expires_at], exist["id"])
    end

    table.insert(cache_ids, exist["id"])
  end

  for expires_at, ids in pairs(update_expires_at_ids) do
    AnalyticsCache:update_expires_at(ids, expires_at)
  end
end

function _M:cache_interval_results(expires_at)
  local day = icu_date.new({
    zone_id = config["analytics"]["timezone"],
  })
  local ok = xpcall(day.parse, xpcall_error_handler, day, format_iso8601, self.end_time)
  if not ok then
    add_error(self.errors, "end_at", "end_at", t("is not valid date"))
    return false
  end
  day:set(icu_date.fields.HOUR_OF_DAY, 23)
  day:set(icu_date.fields.MINUTE, 59)
  day:set(icu_date.fields.SECOND, 59)
  day:set(icu_date.fields.MILLISECOND, 999)
  local end_time_millis = day:get_millis()

  ok = xpcall(day.parse, xpcall_error_handler, day, format_iso8601, self.start_time)
  if not ok then
    add_error(self.errors, "end_at", "end_at", t("is not valid date"))
    return false
  end
  day:set(icu_date.fields.HOUR_OF_DAY, 0)
  day:set(icu_date.fields.MINUTE, 0)
  day:set(icu_date.fields.SECOND, 0)
  day:set(icu_date.fields.MILLISECOND, 0)

  -- Loop through every day within the date range and perform daily searches,
  -- instead of searching for everything all at once.
  local cache_ids = {}
  local batch = {}
  while day:get_millis() <= end_time_millis do
    -- For each day, setup the search instance to just search that day, instead
    -- of the original full date range.
    self:set_start_time(day:format(format_iso8601))

    -- Find the end of the day or month. Set the end time to this next value
    -- minus 1 millisecond (so it's an inclusive end date).
    if self.interval == "month" then
      day:add(icu_date.fields.MONTH, 1)
      day:set(icu_date.fields.DAY_OF_MONTH, 1)
    elseif self.interval == "day" then
      day:add(icu_date.fields.DATE, 1)
    else
      error("Unknown interval")
    end
    day:set(icu_date.fields.HOUR_OF_DAY, 0)
    day:set(icu_date.fields.MINUTE, 0)
    day:set(icu_date.fields.SECOND, 0)
    day:set(icu_date.fields.MILLISECOND, 0)
    day:add(icu_date.fields.MILLISECOND, -1)
    self:set_end_time(day:format(format_iso8601))

    -- If the end date range (eg, end of month) hasn't actually been
    -- encountered yet, then don't cache the results for long, so that it will
    -- be updated as new data comes in.
    if day:get_millis() / 1000 >= ngx.now() then
      local max_expires_at = ngx.now() + 60 * 60 * 6 -- 6 hours
      if expires_at > max_expires_at then
        expires_at = max_expires_at
      end
    end

    -- Check to see if we already have cached data for this exact search query
    -- and date range.
    local cache_id_data = {
      header = self:query_header(),
      body = self:query_body(),

      -- Include the version information in the cache key, so that if the
      -- underlying Elasticsearch database is upgraded, new data will be
      -- fetched.
      api_version = config["elasticsearch"]["api_version"],
      template_version = config["elasticsearch"]["template_version"],
    }
    table.insert(batch, {
      cache_id_data = cache_id_data,
      expires_at = expires_at,
    })
    if #batch >= 200 then
      cache_interval_results_process_batch(self, cache_ids, batch, expires_at)
      batch = {}
    end

    -- Advance the date counter to the next interval.
    day:add(icu_date.fields.MILLISECOND, 1)
  end

  if #batch > 0 then
    cache_interval_results_process_batch(self, cache_ids, batch, expires_at)
  end

  return cache_ids
end

return _M
