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
<p><%= instruction_3 %></p>
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

<%- instruction_3 %>
]])
if template_text_err then
  ngx.log(ngx.ERR, "template compile error: ", template_text_err)
end

return function(admin, token)
  local data = {
    greeting = string.format(t("Hello %s!"), admin.email),
    instruction = t("Someone has requested a link to change your password, and you can do this through the link below."),
    action = t("Change my password"),
    url = build_url("/admins/password/edit?" .. ngx.encode_args({
      reset_password_token = token,
    })),
    instruction_2 = t("If you didn't request this, please ignore this email."),
    instruction_3 = t("Your password won't change until you access the link above and create a new one."),
  }

  local mailer, mailer_err = mail()
  if not mailer then
    return nil, mailer_err
  end

  local ok, send_err = mailer:send({
    headers = config["web"]["mailer"]["headers"],
    from = "noreply@" .. config["web"]["default_host"],
    to = { admin.email },
    subject = t("Reset password instructions"),
    text = template_text(data),
    html = template_html(data),
  })
  if not ok then
    return nil, send_err
  end

  return true
end
