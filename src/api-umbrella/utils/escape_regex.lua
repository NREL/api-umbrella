-- https://github.com/benjamingr/RegExp.escape/blob/master/polyfill.js
return function(value)
  return ngx.re.gsub(value, "[\\\\^$*+?.()|[\\]{}]", "\\$0", "jo")
end
