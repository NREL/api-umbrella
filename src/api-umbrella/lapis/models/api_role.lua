local is_empty = require("pl.types").is_empty
local db = require "lapis.db"
local json_null = require("cjson").null
local model_ext = require "api-umbrella.utils.model_ext"

local db_null = db.NULL

local ApiRole = model_ext.new_class("api_roles", {
  as_json = function(self)
    return {
      id = self.id or json_null,
    }
  end,
}, {
  authorize = function(data)
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

return ApiRole
