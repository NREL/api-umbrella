return function(parsed)
  local url = {}

  if parsed["scheme"] then
    table.insert(url, parsed["scheme"])
    table.insert(url, ":")
  end

  local host = parsed["host"]
  local hostname = parsed["hostname"]
  if host or hostname then
    table.insert(url, "//")

    local userinfo = parsed["userinfo"]
    local user = parsed["user"]
    if userinfo or user then
      if userinfo then
        table.insert(url, userinfo)
      elseif user then
        table.insert(url, user)

        local password = parsed["password"]
        if password then
          table.insert(url, ":")
          table.insert(url, password)
        end
      end

      table.insert(url, "@")
    end

    if host then
      table.insert(url, host)
    elseif hostname then
      table.insert(url, hostname)

      local port = parsed["port"]
      if port then
        table.insert(url, ":")
        table.insert(url, port)
      end
    end
  end

  local path = parsed["path"]
  if path then
    table.insert(url, path)
  end

  local query = parsed["query"]
  if query then
    table.insert(url, query)
  end

  return table.concat(url)
end
