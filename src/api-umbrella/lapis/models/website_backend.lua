local model_ext = require "api-umbrella.utils.model_ext"

local WebsiteBackend = model_ext.new_class("website_backends", {
  as_json = function()
    return {}
  end,
}, {
  authorize = function()
    return true
  end,
})

WebsiteBackend.all_sorted = function(where)
  local sql = ""
  if where then
    sql = sql .. "WHERE " .. where
  end
  sql = sql .. " ORDER BY frontend_host"

  return WebsiteBackend:select(sql)
end

return WebsiteBackend
