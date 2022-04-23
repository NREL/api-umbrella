local build_url = require "api-umbrella.utils.build_url"
local config = require("api-umbrella.utils.load_config")()
local etlua = require "etlua"
local mail = require "api-umbrella.utils.mail"
local t = require("api-umbrella.web-app.utils.gettext").gettext

local template_html, template_html_err = etlua.compile([[
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN" "http://www.w3.org/TR/REC-html40/loose.dtd">
<html><body>
<p><%= greeting %></p>

<p><%= instruction %></p>

<p><a href="<%= url %>"><%= action %></a></p>

<p><%= instruction_2 %></p>
</body></html>
]])
if template_html_err then
  ngx.log(ngx.ERR, "template compile error: ", template_html_err)
end

local template_text, template_text_err = etlua.compile([[
<%- greeting %>

<%- instruction %>

<%- action %> ( <%- url %> )

<%- instruction_2 %>
]])
if template_text_err then
  ngx.log(ngx.ERR, "template compile error: ", template_text_err)
end

return function(admin, token)
  local data = {
    greeting = string.format(t("Hi %s,"), admin.email),
    instruction_2 = t("If you didn't request an account, please ignore this email."),
  }

  if token then
    data["instruction"] = string.format(t("Welcome to the %s admin. To get started, set your password with the link below."), config["site_name"])
    data["action"] = t("Set my password")
    data["url"] = build_url("/admins/password/edit?" .. ngx.encode_args({
      reset_password_token = token,
      invite = "true",
    }))
  else
    data["instruction"] = string.format(t("Welcome to the %s admin. To get started, sign in with an account associated with your %s email address at the link below."), config["site_name"], admin.email)
    data["action"] = t("Admin sign in")
    data["url"] = build_url("/admin/login")
  end

  local mailer, mailer_err = mail()
  if not mailer then
    return nil, mailer_err
  end

  local ok, send_err = mailer:send({
    headers = config["web"]["mailer"]["headers"],
    from = "noreply@" .. config["web"]["default_host"],
    to = { admin.email },
    subject = string.format(t("%s Admin Access"), config["site_name"]),
    text = template_text(data),
    html = template_html(data),
  })
  if not ok then
    return nil, send_err
  end

  return true
end
