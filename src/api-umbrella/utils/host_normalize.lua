return function(host)
  if host then
    return string.lower(string.match(host, "[^:]*"))
  else
    return nil
  end
end
