return function(host)
  if host then
    return string.match(host, "[^:]*")
  else
    return nil
  end
end
