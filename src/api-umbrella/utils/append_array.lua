-- Append an array to the end of the destination array.
--
-- In benchmarks, appears faster than moses.append and pl.tablex.move
-- implementations.
return function(dest, src)
  if type(dest) ~= "table" or type(src) ~= "table" then return end

  local dest_length = #dest
  local src_length = #src
  for i = 1, src_length do
    dest[dest_length + i] = src[i]
  end

  return dest
end
