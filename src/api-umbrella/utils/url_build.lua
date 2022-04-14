return function(parsed)
  local url = {}

  if parsed["scheme"] then
    table.insert(url, parsed["scheme"])
    table.insert(url, ":")
  end

  local host = parsed["host"]
  if host then
    table.insert(url, "//")

    local user = parsed["user"]
    if user then
      table.insert(url, user)

      local password = parsed["password"]
      if password then
        table.insert(url, ":")
        table.insert(url, password)
      end

      table.insert(url, "@")
    end

    table.insert(url, host)

    local port = parsed["port"]
    if port then
      table.insert(url, ":")
      table.insert(url, port)
    end
  end

  local path = parsed["path"]
  if path then
    table.insert(url, path)
  end

  local query = parsed["query"]
  if query then
    table.insert(url, "?")
    table.insert(url, query)
  end

  local fragment = parsed["fragment"]
  if fragment then
    table.insert(url, "#")
    table.insert(url, fragment)
  end

  return table.concat(url)
end
