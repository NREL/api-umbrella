local tablex = require "pl.tablex"

local find = tablex.find

return function(table, value)
  return (find(table, value) ~= nil)
end
