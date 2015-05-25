local plutils = require "pl.utils"
local utf8 = require "lua-utf8"
local utils = require "utils"
local inspect = require "inspect"

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

function _M.set_request_hierarchy(data)
  -- To make drill-downs queries easier, index the host and path so that a
  -- request like:
  --
  -- http://example.com/api/foo/bar.json?param=example
  --
  -- Gets indexed as this array:
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
  local request_hierarchy = {}
  local hierarchy_string = data["request_host"] .. data["request_path"]

  -- Remote duplicate slashes (eg foo//bar becomes foo/bar).
  hierarchy_string = string.gsub(hierarchy_string, "//+", "/")

  -- Remove trailing slashes. This is so that we can always distinguish the
  -- intermediate paths versus the actual endpoint.
  hierarchy_string = string.gsub(hierarchy_string, "/$", "")

  local hierarchy_parts = split(hierarchy_string, "/")
  for index, _ in ipairs(hierarchy_parts) do
    local parents_and_self = {}
    for i = 1, index do
      table.insert(parents_and_self, hierarchy_parts[i])
    end

    local token = (index - 1) .. "/" .. table.concat(parents_and_self, "/")

    -- Add a trailing slash to all parent tokens, but not the last token. This
    -- is done for two reasons:
    --
    -- 1. So we can distinguish between paths with common prefixes (for example
    --    /api/books vs /api/book)
    -- 2. So we can distinguish intermediate parents from the "leaf" token (for
    --    example, we know how to distinguish "/api/foo" when there are two
    --    requests to "/api/foo" and "/api/foo/bar"--in the first, /api/foo is
    --    the actual API call, whereas in the second, /api/foo is just an
    --    intermediate path).
    if index < #hierarchy_parts then
      token = token .. "/"
    end

    table.insert(request_hierarchy, token)
  end

  data["request_hierarchy"] = request_hierarchy
end

function _M.recursive_utf8_escape(data)
  if not data then return end

  for key, value in pairs(data) do
    if type(value) == "string" then
      data[key] = utf8.escape(value)
    elseif type(value) == "table" then
      _M.recursive_utf8_escape(value)
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
  data["request_path"] = parts[1]

  -- Extract the query string arguments (minus "api_key" which we want to mask
  -- from logging in the URL fields that will be shown in the admin interface).
  --
  -- Note: We're using the original args (rather than the current args, where
  -- we may have already removed this field), since we want the logged URL to
  -- reflect the original URL (and not after any internal rewriting).
  local args = utils.remove_arg(parts[2], "api_key")
  if args then
    data["request_query"] = ngx.decode_args(args)

    -- Since we decoded the argument string to construct the table of
    -- arguments, we now might have invalid or wonky characters that will cause
    -- invalid JSON and prevent ElasticSearch from indexing the request. So run
    -- through all the arguments and escape them.
    _M.recursive_utf8_escape(data["request_query"])
  end

  -- Construct the full URL.
  data["request_url"] = data["request_scheme"] .. "://" .. data["request_host"] .. data["request_path"]
  if args then
    data["request_url"] = data["request_url"] .. "?" .. args
  end
end

return _M
