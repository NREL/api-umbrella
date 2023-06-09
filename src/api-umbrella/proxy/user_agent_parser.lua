local lrucache = require "resty.lrucache.pureffi"
local data = require "api-umbrella.proxy.user_agent_parser_data"

local re_match = ngx.re.match

-- local data = user_agent_parser_data
local cache = lrucache.new(500)

return function(user_agent)
  if not user_agent then
    return nil
  end

  local result = cache:get(user_agent)
  if result then
    return result
  end

  result = {}

  for _, robot in ipairs(data["robots"]) do
    if user_agent == robot["useragent"] then
      result["type"] = "Robot"
      result["family"] = robot["family"]
      return result
    end
  end

  for _, browser_regex in ipairs(data["browser_regexes"]) do
    local matches, match_err = re_match(user_agent, browser_regex["regex"], browser_regex["regex_flags"])
    if matches then
      local browser = data["browsers"][browser_regex["browser_id"]]
      if browser then
        result["family"] = browser["name"]

        local browser_type = data["browser_types"][browser["type"]]
        if browser_type then
          result["type"] = browser_type["type"]
        end
      end

      if matches[1] then
        result["version"] = matches[1]
      end

      break
    elseif match_err then
      ngx.log(ngx.ERR, "regex error: ", match_err)
    end
  end

  cache:set(user_agent, result)

  return result
end
