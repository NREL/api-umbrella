local gsub = string.gsub

return function(template, data, escape)
  local function replace(capture)
    local replacement = data[capture]
    if replacement and escape then
      replacement = escape(replacement)
    end

    return replacement
  end

  return gsub(template, "{{ *([^}]*) *}}", replace)
end
