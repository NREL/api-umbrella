local httpsify_current_url = require "api-umbrella.utils.httpsify_current_url"
local re_find = ngx.re.find

return function(regex)
  if not regex then return end

  local protocol = ngx.ctx.protocol
  if protocol ~= "https" then
    local find_from, _, find_err = re_find(ngx.ctx.original_uri_path, regex, "ijo")
    if find_from then
      return ngx.redirect(httpsify_current_url(), ngx.HTTP_MOVED_PERMANENTLY)
    elseif find_err then
      ngx.log(ngx.ERR, "regex error: ", find_err)
    end
  end
end
