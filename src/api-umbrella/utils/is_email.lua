local re_find = ngx.re.find

return function(str)
  local find_from, _, find_err = re_find(str, [[^[^\s/@]+@[^\s/@]+\.[^\s/@]+$]], "jo")
  if find_err then
    ngx.log(ngx.ERR, "regex error: ", find_err)
    return false
  end

  if find_from then
    return true
  else
    return false
  end
end
