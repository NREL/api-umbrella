local alpha_numeric  = {
  "A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M",
  "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z",
  "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m",
  "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
  "0", "1", "2", "3", "4", "5", "6", "7", "8", "9"
}

local alpha_numeric_size = #alpha_numeric

if ngx then
  math.randomseed(ngx.time())
else
  math.randomseed(os.time())
end

return function(length)
  local token = {}
  for i = 1, length do
    token[i] = alpha_numeric[math.random(alpha_numeric_size)]
  end

  return table.concat(token)
end
