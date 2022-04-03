local gsub = string.gsub
local search = "[\"'&<>]"
local replace = {
  ['"'] = "&quot;",
  ["'"] = "&#39;",
  ["&"] = "&amp;",
  ["<"] = "&lt;",
  [">"] = "&gt;",
}

return function(value)
  return gsub(value, search, replace)
end
