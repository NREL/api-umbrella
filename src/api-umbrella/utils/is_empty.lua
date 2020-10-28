return function(obj)
  if obj == nil then
    return true
  end

  local obj_type = type(obj)
  if obj_type == "string" and obj == "" then
    return true
  elseif obj_type == "table" and next(obj) == nil then
    return true
  end

  return false
end
