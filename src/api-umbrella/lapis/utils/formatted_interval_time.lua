local iso8601 = require "api-umbrella.utils.iso8601"
local luatz = require "luatz"
local timezone = luatz.get_tz(config["analytics"]["timezone"])
local time = require "posix.time"

return function(search, timestamp)
  local tm = time.localtime(timestamp / 1000)
  ngx.log(ngx.ERR, "TIMESTAMP: " .. inspect(timestamp))
  ngx.log(ngx.ERR, "TM: " .. inspect(tm))

  local interval = search.interval
  if interval == "minute" then
    return time.strftime("%a, %b %d, %Y %I:%M%p %Z", tm)
  elseif interval == "hour" then
    return time.strftime("%FT%T %Z", tm)
  elseif interval == "day" then
    return time.strftime("%a, %b %d, %Y", tm)
  elseif interval == "week" then
    local end_of_week = time:copy()
    end_of_week:setisoweeknumber(time:getisoweeknumber() + 1)
    end_of_week:addseconds(-1)

    local format = "%b %d, %Y"
    return time:fmt(format) .. " - " .. end_of_week:fmt(format)
  elseif interval == "month" then
    local end_of_month = time:copy()
    end_of_month:setmonth(time:getmonth() + 1)
    end_of_month:addseconds(-1)

    local format = "%b %d, %Y"
    return time:fmt(format) .. " - " .. end_of_month:fmt(format)
  end

  --[[
  ngx.log(ngx.ERR, "TIMESTAMP: " .. inspect(timestamp))
  local time = iso8601.parse_timestamp(timestamp / 1000)
  ngx.log(ngx.ERR, "TIME: " .. inspect(time) .. ": " .. time:fmt("%a, %b %d, %Y %I:%M%p %Z"))
  local tz = timezone:find_current(timestamp / 1000)
  ngx.log(ngx.ERR, "TZ: " .. inspect(tz))
  --ngx.log(ngx.ERR, "TZ: " .. luatz.strftime.strftime("%a, %b %d, %Y %I:%M%p %Z", tz:normalise()))

  local interval = search.interval
  if interval == "minute" then
    return time:fmt("%a, %b %d, %Y %I:%M%p %Z")
  elseif interval == "hour" then
    return time:fmt("%a, %b %d, %Y %I:%M%p %Z")
  elseif interval == "day" then
    return time:fmt("%a, %b %d, %Y")
  elseif interval == "week" then
    local end_of_week = time:copy()
    end_of_week:setisoweeknumber(time:getisoweeknumber() + 1)
    end_of_week:addseconds(-1)

    local format = "%b %d, %Y"
    return time:fmt(format) .. " - " .. end_of_week:fmt(format)
  elseif interval == "month" then
    local end_of_month = time:copy()
    end_of_month:setmonth(time:getmonth() + 1)
    end_of_month:addseconds(-1)

    local format = "%b %d, %Y"
    return time:fmt(format) .. " - " .. end_of_month:fmt(format)
  end
  ]]
end
