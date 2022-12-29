local gsub = ngx.re.gsub

return function(value)
  return '"' .. gsub(value, '"', '""', "jo") .. '"'
end
