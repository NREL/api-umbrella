local db = require "lapis.db"
local is_empty = require "api-umbrella.utils.is_empty"
local json_null_default = require "api-umbrella.web-app.utils.json_null_default"
local model_ext = require "api-umbrella.web-app.utils.model_ext"

local db_null = db.NULL

local ApiRole = model_ext.new_class("api_roles", {
  as_json = function(self)
    return {
      id = json_null_default(self.id),
    }
  end,
}, {
  authorize = function()
    return true
  end,
})

ApiRole.insert_missing = function(ids)
  if not is_empty(ids) and ids ~= db_null then
    for _, id in ipairs(ids) do
      db.query("INSERT INTO api_roles(id) VALUES(?) ON CONFLICT DO NOTHING", id)
    end
  end
end

ApiRole.all_ids = function()
  local ids = {}
  local roles = ApiRole:select({ fields = "id", load = false })
  for _, role in ipairs(roles) do
    table.insert(ids, role.id)
  end

  return ids
end

return ApiRole
