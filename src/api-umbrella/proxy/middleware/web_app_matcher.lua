return function()
  local web_app_host = config["router"]["web_app_host"]
  if web_app_host == "*" or ngx.ctx.host_normalized == web_app_host then
    local matches, match_err = ngx.re.match(ngx.ctx.original_uri, config["router"]["web_app_backend_regex"], "ijo")
    if matches then
      return true
    elseif match_err then
      ngx.log(ngx.ERR, "regex error: ", match_err)
    end
  end

  return false
end
