local gsub = ngx.re.gsub

return function(number)
  return gsub(tostring(number), [[(\d)(?=(\d{3})+$)]], "$1,")
end
