local config = require("api-umbrella.utils.load_config")()
local etlua = require "etlua"
local mail = require "api-umbrella.utils.mail"
local t = require("api-umbrella.web-app.utils.gettext").gettext

local template_html, template_html_err = etlua.compile([[
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.0 Transitional//EN" "http://www.w3.org/TR/REC-html40/loose.dtd">
<html><body>
<h1><%= subject %></h1>

<h2><%= t("Description") %></h2>
<p><%= use_description %></p>

<h2><%= t("Extra Information") %></h2>

<table>
  <tr>
    <td><%= t("Email") %></td>
    <td><%= email %></td>
  </tr>
  <% if registration_source then %>
    <tr>
      <td><%= t("Source") %></td>
      <td><%= registration_source %></td>
    </tr>
  <% end %>
  <% if website then %>
    <tr>
      <td><%= t("Website") %></td>
      <td><%= website %></td>
    </tr>
  <% end %>
  <tr>
    <td><%= t("IP Address") %></td>
    <td><%= registration_ip %></td>
  </tr>
  <tr>
    <td><%= t("Referer") %></td>
    <td><%= registration_referer %></td>
  </tr>
  <tr>
    <td><%= t("Origin") %></td>
    <td><%= registration_origin %></td>
  </tr>
</table>
</body></html>
]])
if template_html_err then
  ngx.log(ngx.ERR, "template compile error: ", template_html_err)
end

return function(api_user)
  local mailer, mailer_err = mail()
  if not mailer then
    return nil, mailer_err
  end

  local from = "noreply@" .. config["web"]["default_host"]
  local to = config["web"]["admin_notify_email"]
  if not to then
    to = config["web"]["contact_form_email"]
  end

  local full_name = (api_user.first_name or "") .. " " .. (api_user.last_name or "")
  local subject = string.format(t("%s just subscribed"), full_name)

  local data = {
    subject = subject,
    use_description = api_user.use_description,
    email = api_user.email,
    registration_source = api_user.registration_source,
    website = api_user.website,
    registration_ip = api_user.registration_ip,
    registration_referer = api_user.registration_referer,
    registration_origin = api_user.registration_origin,
    t = t,
  }

  local ok, send_err = mailer:send({
    headers = config["web"]["mailer"]["headers"],
    from = from,
    to = { to },
    subject = subject,
    html = template_html(data),
  })
  if not ok then
    return nil, send_err
  end

  return true

end
