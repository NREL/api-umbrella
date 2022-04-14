local re_match = ngx.re.match

-- Regex based on https://datatracker.ietf.org/doc/html/rfc3986#appendix-B with
-- tweaks to extract some of the details separately (eg, user, password, host
-- instead of just authority).
local regex = [[
  ^
  (?:
    ([^:/?#]+) # scheme
  :)?
  (?:
    //
    (?:
      ([^:@/?#]*)? # user
      (?:
        :
        ([^:@/?#]*) # password
      )?
    @)?
    (
      [^/?#:]+
      |
      \[[a-f0-9\:]+\]
    ) # host
    (?:
      :
      (\d+) # port
    )?
  )?
  ([^?#]*) # path
  (?:
    \?
    ([^#]*) # query
  )?
  (?:
    \#
    (.*) # fragment
  )?
  $
]]

return function(url)
  local matches, err = re_match(url, regex, "ijox")
  if err then
    return nil, err
  end

  return {
    scheme = matches[1] ~= false and matches[1] or nil,
    user = matches[2] ~= false and matches[2] or nil,
    password = matches[3] ~= false and matches[3] or nil,
    host = matches[4] ~= false and matches[4] or nil,
    port = matches[5] ~= false and matches[5] or nil,
    path = matches[6] ~= false and matches[6] or nil,
    query = matches[7] ~= false and matches[7] or nil,
    fragment = matches[8] ~= false and matches[8] or nil,
  }
end
