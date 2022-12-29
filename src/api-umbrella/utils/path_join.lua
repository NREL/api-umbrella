local flatten = require "api-umbrella.utils.flatten"

local gsub = ngx.re.gsub

-- Join parts of file paths by the "/" separator.
--
-- This joins paths like Ruby's File.join(), which differs from Penlight's
-- path.join. Unlike Penlight's path.join, this does not treat beginning
-- slashes as absolute paths (so joining "foo" and "/bar" results in "foo/bar"
-- with this method, unlike Penlight returning just "/bar").
--
-- Adheres to these specs:
-- https://github.com/ruby/spec/blob/6bf1725bafd0393c1f031b62a7234fb76087fd46/core/file/join_spec.rb
return function(...)
  local joined = ""
  local parts = flatten({...})
  for index, part in ipairs(parts) do
    local part_first_char = string.sub(part, 1, 1)
    if part_first_char == "/" then
      joined = gsub(joined, "/+$", "", "jo")
    elseif index ~= 1 then
      local joined_last_char = string.sub(joined, -1)
      if joined_last_char ~= "/" then
        joined = joined .. "/"
      end
    end

    joined = joined .. part
  end

  return joined
end
