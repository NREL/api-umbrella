local build_url = require "api-umbrella.utils.build_url"
local etlua = require "etlua"
local smtp = require "api-umbrella.utils.smtp"
local t = require("resty.gettext").gettext

local template_html = etlua.compile([[
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN" "http://www.w3.org/TR/REC-html40/loose.dtd">
<html><body>
<p><%= greeting %></p>

<p><%= instruction %></p>

<p><a href="<%= url %>"><%= action %></a></p>

<p><%= instruction_2 %></p>
<p><%= instruction_3 %></p>
</body></html>
]])

local template_text = etlua.compile([[
<%- greeting %>

<%- instruction %>

<%- action %> ( <%- url %> )

<%- instruction_2 %>

<%- instruction_3 %>
]])

return function(admin, token)
  local data = {
    greeting = string.format(t("Hello %s!"), admin.email),
    instruction = t("Someone has requested a link to change your password, and you can do this through the link below."),
    action = t("Change my password"),
    url = build_url("/admins/password/edit?reset_password_token=" .. token),
    instruction_2 = t("If you didn't request this, please ignore this email."),
    instruction_3 = t("Your password won't change until you access the link above and create a new one."),
  }

  ngx.log(ngx.ERR, template_html(data))
  ngx.log(ngx.ERR, template_text(data))

  local smtp_conn = smtp.new({
    host = config["emailrelay"]["host"],
    port = config["emailrelay"]["port"],
  })

  local ret, err = smtp_conn:send({
    from = "noreply@localhost",
    to = admin.email,
    subject = t("Reset password instructions"),
    text = template_text(data),
    html = template_html(data),
  })
  ngx.log(ngx.ERR, "SMTP RET: " .. inspect(ret))
  ngx.log(ngx.ERR, "SMTP ERR: " .. inspect(err))
end
