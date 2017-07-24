local _M = {}

function _M.new()
end

function _M.create()
end

function _M.show()
end

return function(app)
  app:get("/admins/unlock/new(.:format)", _M.new)
  app:post("/admins/unlock(.:format)", _M.create)
  app:get("/admins/unlock(.:format)", _M.show)
end
