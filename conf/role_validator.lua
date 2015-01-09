local moses = require "moses"
local inspect = require "inspect"

return function(settings, user)
  local required_roles = settings["required_roles"]

  local authenticated = true
  if not moses.isEmpty(required_roles) then
    authenticated = false

    local user_roles = user["roles"]
    if user_roles then
      if user_roles["admin"] then
        authenticated = true
      else
        for _, required_role in ipairs(required_roles) do
          if user_roles[required_role] then
            authenticated = true
            break
          end
        end
      end
    end
  end

  if not authenticated then
    return "api_key_unauthorized"
  end
end
