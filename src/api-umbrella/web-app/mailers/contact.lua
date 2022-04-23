local config = require("api-umbrella.utils.load_config")()
local etlua = require "etlua"
local mail = require "api-umbrella.utils.mail"
local t = require("api-umbrella.web-app.utils.gettext").gettext

local template_text, template_text_err = etlua.compile([[
Name: <%- name %>
Email: <%- email %>
API: <%- api %>
Subject: <%- subject %>

-------------------------------------

<%- message %>

-------------------------------------
]])
if template_text_err then
  ngx.log(ngx.ERR, "template compile error: ", template_text_err)
end

return function(data)
  local mailer, mailer_err = mail()
  if not mailer then
    return nil, mailer_err
  end

  local from = "noreply@" .. config["web"]["default_host"]
  local to = config["web"]["contact_form_email"]
  local reply_to = data["email"]
  local subject = string.format(t("%s Contact Message from %s"), config["site_name"], data["email"])

  local ok, send_err = mailer:send({
    headers = config["web"]["mailer"]["headers"],
    from = from,
    to = { to },
    reply_to = reply_to,
    subject = subject,
    text = template_text(data),
  })
  if not ok then
    return nil, send_err
  end

  return true

end
