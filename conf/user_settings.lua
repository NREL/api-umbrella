local inspect = require "inspect"
local tablex = require "pl.tablex"
local utils = require "utils"

local merge_settings = utils.merge_settings
local deepcopy = tablex.deepcopy

return function(settings, user)
  settings["original_api_settings"] = deepcopy(settings)

  if user and user["settings"] then
    settings["original_user_settings"] = deepcopy(user["settings"])
    merge_settings(settings, settings["original_user_settings"])
  end
end
