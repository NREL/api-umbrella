local iso8601 = require "api-umbrella.utils.iso8601"

return function(search, timestamp)
  local time = iso8601.parse_timestamp(timestamp / 1000)

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
end
