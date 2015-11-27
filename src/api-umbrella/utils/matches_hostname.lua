return function(normalized_hostname, wildcard_regex)
  if wildcard_regex then
    local matches, match_err = ngx.re.match(ngx.ctx.host_normalized, wildcard_regex, "jo")
    if matches then
      return true
    elseif match_err then
      ngx.log(ngx.ERR, "regex error: ", match_err)
    end
  else
    if ngx.ctx.host_normalized == normalized_hostname then
      return true
    end
  end

  return false
end
