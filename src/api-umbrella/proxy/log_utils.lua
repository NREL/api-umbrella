local escape_uri_non_ascii = require "api-umbrella.utils.escape_uri_non_ascii"
local plutils = require "pl.utils"

local split = plutils.split

local _M = {}

_M.MSEC_FIELDS = {
  "backend_response_time",
  "internal_gatekeeper_time",
  "proxy_overhead",
  "request_at",
  "response_time",
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
  ngx.log(ngx.ERR, "CLEANED PATH: " .. inspect(cleaned_path))
  local path_parts = split(cleaned_path, "/", true, 6)

  -- Setup top-level host hierarchy for ElasticSearch storage.
  data["request_url_hierarchy"] = {}
  local host_token = "0/" .. data["request_url_host"]
  if #path_parts > 0 then
    host_token = host_token .. "/"
  end
  table.insert(data["request_url_hierarchy"], host_token)

  ngx.log(ngx.ERR, "PATH PARTS: " .. inspect(path_parts))
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
  end

  set_url_hierarchy(data)
end

return _M
