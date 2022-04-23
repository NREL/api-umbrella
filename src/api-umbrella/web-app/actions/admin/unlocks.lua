local config = require("api-umbrella.utils.load_config")()
local csrf = require "api-umbrella.web-app.utils.csrf"
local respond_to = require "api-umbrella.web-app.utils.respond_to"

local _M = {}

function _M.new()
end

function _M.create()
end

function _M.show()
end

return function(app)
  if config["web"]["admin"]["auth_strategies"]["_enabled"]["local"] then
    app:match("/admins/unlock/new(.:format)", respond_to({ GET = _M.new }))
    app:match("/admins/unlock(.:format)", respond_to({
      POST = csrf.validate_token_filter(_M.create),
      GET = _M.show,
    }))
  end
end
