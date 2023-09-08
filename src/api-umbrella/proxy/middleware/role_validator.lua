local is_empty = require "api-umbrella.utils.is_empty"

return function(settings, user)
  local required_roles = settings["_required_roles"]

  -- If this API doesn't require any roles, no need to check anything, so
  -- continue on.
  if is_empty(required_roles) then
    return nil
  end

  local authenticated = false
  if user then
    -- Check to see if the user has any of the required roles, or the special
    -- "admin" role.
    local user_roles = user["roles"]
    if not is_empty(user_roles) then
      for _, required_role in ipairs(required_roles) do
        if user_roles[required_role] then
          authenticated = true
        else
          authenticated = false
          break
        end
      end
    end
  end

  if not authenticated then
    return "api_key_unauthorized"
  end
end
