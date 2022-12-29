local re_find = ngx.re.find

return function(normalized_hostname, wildcard_regex)
  if wildcard_regex then
    local find_from, _, find_err = re_find(ngx.ctx.host_normalized, wildcard_regex, "jo")
    if find_from then
      return true
    elseif find_err then
      ngx.log(ngx.ERR, "regex error: ", find_err)
    end
  else
    if ngx.ctx.host_normalized == normalized_hostname then
      return true
    end
  end

  return false
end
