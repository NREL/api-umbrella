local escape_uri_non_ascii = require "api-umbrella.utils.escape_uri_non_ascii"
local plutils = require "pl.utils"

local split = plutils.split

local _M = {}

_M.MSEC_FIELDS = {
  "timer_backend_response",
  "timer_internal",
  "timer_proxy_overhead",
  "timer_response",
  "timestamp_utc",
}

function _M.ignore_request()
  -- Don't log some of our internal API calls used to determine if API Umbrella
  -- is fully started and ready (since logging of these requests will likely
  -- fail anyway if things aren't ready).
  local uri = ngx.ctx.original_uri or ngx.var.uri
  if uri == "/api-umbrella/v1/health" or uri == "/api-umbrella/v1/state" then
    return true
  else
    return false
  end
end

-- To make drill-downs queries easier, split up how the path is stored.
--
-- We store this in slightly different, but similar fashions for SQL storage
-- versus ElasticSearch storage.
--
-- A request like this:
--
-- http://example.com/api/foo/bar.json?param=example
--
-- Will get stored like this for SQL storage:
--
-- request_url_path_level1 = /api/
-- request_url_path_level2 = /api/foo/
-- request_url_path_level3 = /api/foo/bar.json
--
-- And gets indexed as this array for ElasticSearch storage:
--
-- 0/example.com/
-- 1/example.com/api/
-- 2/example.com/api/foo/
-- 3/example.com/api/foo/bar.json
--
-- This is similar to ElasticSearch's built-in path_hierarchy tokenizer, but
-- prefixes each token with a depth counter, so we can more easily and
-- efficiently facet on specific levels (for example, a regex query of "^0/"
-- would return all the totals for each domain).
--
-- See:
-- http://wiki.apache.org/solr/HierarchicalFaceting
-- http://www.springyweb.com/2012/01/hierarchical-faceting-with-elastic.html
local function set_url_hierarchy(data)
  -- Remote duplicate slashes (eg foo//bar becomes foo/bar).
  local cleaned_path = ngx.re.gsub(data["request_url_path"], "//+", "/", "jo")

  -- Remove trailing slashes. This is so that we can always distinguish the
  -- intermediate paths versus the actual endpoint.
  cleaned_path = ngx.re.gsub(cleaned_path, "/$", "", "jo")

  -- Remove the slash prefix so that split doesn't return an empty string as
  -- the first element.
  cleaned_path = ngx.re.gsub(cleaned_path, "^/", "", "jo")

  -- Split the path by slashes limiting to 6 levels deep (everything beyond
  -- the 6th level will be included on the 6th level string). This is to
  -- prevent us from having to have unlimited depths for flattened SQL storage.
  local path_parts = split(cleaned_path, "/", true, 6)

  -- Setup top-level host hierarchy for ElasticSearch storage.
  data["request_url_hierarchy"] = {}
  local host_token = "0/" .. data["request_url_host"]
  if #path_parts > 0 then
    host_token = host_token .. "/"
  end
  table.insert(data["request_url_hierarchy"], host_token)

  local path_level = "/"
  for index, _ in ipairs(path_parts) do
    path_level = path_level .. path_parts[index]

    -- Add a trailing slash to all parent paths, but not the last path. This
    -- is done for two reasons:
    --
    -- 1. So we can distinguish between paths with common prefixes (for example
    --    /api/books vs /api/book)
    -- 2. So we can distinguish intermediate parents from the "leaf" path (for
    --    example, we know how to distinguish "/api/foo" when there are two
    --    requests to "/api/foo" and "/api/foo/bar"--in the first, /api/foo is
    --    the actual API call, whereas in the second, /api/foo is just an
    --    intermediate path).
    if index < #path_parts then
      path_level = path_level .. "/"
    end

    -- Store in the request_url_path_level(1-6) fields for SQL storage.
    data["request_url_path_level" .. index] = path_level

    -- Store as an array for ElasticSearch storage.
    local path_token = index .. "/" .. data["request_url_host"] .. path_level
    table.insert(data["request_url_hierarchy"], path_token)
  end
end

local function recursive_elasticsearch_sanitize(data)
  if not data then return end

  for key, value in pairs(data) do
    if type(value) == "string" then
      -- Escaping any non-ASCII chars to prevent invalid or wonky UTF-8
      -- sequences from generating invalid JSON that will prevent ElasticSearch
      -- from indexing the request.
      data[key] = escape_uri_non_ascii(value)
    elseif type(value) == "table" then
      recursive_elasticsearch_sanitize(value)
    end

    -- As of ElasticSearch 2, field names cannot contain dots. This affects our
    -- nested hash of query parameters, since incoming query parameters may
    -- contain dots. For storage purposes, replace these dots with underscores
    -- (the same approach LogStash's de_dot plugin takes).
    --
    -- See:
    -- https://www.elastic.co/guide/en/elasticsearch/reference/2.0/breaking_20_mapping_changes.html#_field_names_may_not_contain_dots
    --
    -- However, dots look like they'll be allowed again (although, treated as
    -- nested objects) in ElasticSearch 5:
    -- https://github.com/elastic/elasticsearch/issues/15951
    -- https://github.com/elastic/elasticsearch/pull/18106
    -- https://www.elastic.co/blog/elasticsearch-5-0-0-alpha3-released#_dots_in_field_names
    local sanitized_key = ngx.re.gsub(key, "\\.", "_", "jo")
    if key ~= sanitized_key then
      data[sanitized_key] = data[key]
      data[key] = nil
    end
  end
end

function _M.set_url_fields(data)
  -- Extract just the path portion of the URL.
  --
  -- Note: we're extracting this from the original "request_uri" variable here,
  -- rather than just using the original "uri" variable by itself, since
  -- "request_uri" has the raw encoding of the URL as it was passed in (eg, for
  -- url escaped encodings), which we'll prefer for consistency.
  local parts = split(ngx.ctx.original_request_uri, "?", true, 2)
  data["request_url_path"] = escape_uri_non_ascii(parts[1])

  -- Extract the query string arguments.
  --
  -- Note: We're using the original args (rather than the current args, where
  -- we may have already removed this field), since we want the logged URL to
  -- reflect the original URL (and not after any internal rewriting).
  if parts[2] then
    data["request_url_query"] = escape_uri_non_ascii(parts[2])
    data["legacy_request_url_query_hash"] = ngx.decode_args(data["request_url_query"])

    -- Since we decoded the argument string to construct the table of
    -- arguments, we now must recursively prepare it for ElasticSearch storage.
    recursive_elasticsearch_sanitize(data["legacy_request_url_query_hash"])
  end

  data["legacy_request_url"] = data["request_url_scheme"] .. "://" .. data["request_url_host"] .. data["request_url_path"]
  if data["request_url_query"] then
    data["legacy_request_url"] = data["legacy_request_url"] .. "?" .. data["request_url_query"]
  end

  set_url_hierarchy(data)
end

function _M.truncate_header(value, max_length)
  if not value or type(value) ~= "string" then
    return value
  end

  if string.len(value) > max_length then
    return string.sub(value, 1, max_length)
  else
    return value
  end
end

return _M
