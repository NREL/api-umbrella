local inspect = require "inspect"
local tablex = require "pl.tablex"
local utils = require "utils"

local deep_merge_overwrite_arrays = utils.deep_merge_overwrite_arrays
local deepcopy = tablex.deepcopy

return function(settings, user)
  settings["original_api_settings"] = deepcopy(settings)

  if user and user["settings"] then
    settings["original_user_settings"] = deepcopy(user["settings"])
    deep_merge_overwrite_arrays(settings, settings["original_user_settings"])
  end
end
