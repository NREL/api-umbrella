local t = require("api-umbrella.web-app.utils.gettext").gettext

return function(current_admin)
  if not current_admin then
    ngx.ctx.error_status = 401
    coroutine.yield("error", {
      _render = {
        ["error"] = t("You need to sign in or sign up before continuing."),
      },
    })
  else
    local authorized_scopes_list = {}
    local api_scopes = current_admin:api_scopes()
    for _, api_scope in ipairs(api_scopes) do
      table.insert(authorized_scopes_list, "- " .. (api_scope.host or "") .. (api_scope.path_prefix or ""))
    end
    table.sort(authorized_scopes_list)

    ngx.ctx.error_status = 403
    coroutine.yield("error", {
      _render = {
        errors = {
          {
            code = "FORBIDDEN",
            message = string.format(t("You are not authorized to perform this action. You are only authorized to perform actions for APIs in the following areas:\n\n%s\n\nContact your API Umbrella administrator if you need access to new APIs."), table.concat(authorized_scopes_list, "\n")),
          },
        },
      },
    })
  end

  return false
end
