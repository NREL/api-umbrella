local encode_array = require("pgmoon.arrays").encode_array

-- Wrapper around pgmoon's default encode_array to fix empty array handling:
-- https://github.com/leafo/pgmoon/issues/37
return function(tbl, escape_literal)
  if type(tbl) == "table" and #tbl == 0 then
    return "'{}'"
  else
    return encode_array(tbl, escape_literal)
  end
end
