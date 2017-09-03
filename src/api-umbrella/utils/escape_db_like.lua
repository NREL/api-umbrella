return function(value)
  local result, _, gsub_err = ngx.re.gsub(value, "[%_\\\\]", "\\$0", "jo")
  if gsub_err then
    ngx.log(ngx.ERR, "regex error: ", gsub_err)
  end

  return result
end
