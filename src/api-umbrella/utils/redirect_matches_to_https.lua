local httpsify_current_url = require "api-umbrella.utils.httpsify_current_url"

return function(regex)
  if not regex then return end

  local protocol = ngx.ctx.protocol
  if protocol ~= "https" then
    local matches, match_err = ngx.re.match(ngx.ctx.original_uri, regex, "ijo")
    if matches then
      return ngx.redirect(httpsify_current_url(), ngx.HTTP_MOVED_PERMANENTLY)
    elseif match_err then
      ngx.log(ngx.ERR, "regex error: ", match_err)
    end
  end
end
