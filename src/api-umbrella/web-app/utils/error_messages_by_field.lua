return function(errors)
  local messages = {}
  if errors then
    for _, error_data in ipairs(errors) do
      assert(error_data["field"])
      assert(error_data["message"])

      local field = error_data["field"]

      if not messages[field] then
        messages[field] = {}
      end

      table.insert(messages[field], error_data["message"])
    end

    for field, _ in pairs(messages) do
      table.sort(messages[field])
    end
  end

  return messages
end
