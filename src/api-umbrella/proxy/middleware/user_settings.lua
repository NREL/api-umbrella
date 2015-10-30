local deep_merge_overwrite_arrays = require "api-umbrella.utils.deep_merge_overwrite_arrays"
local tablex = require "pl.tablex"

local deepcopy = tablex.deepcopy

return function(settings, user)
  settings["original_api_settings"] = deepcopy(settings)

  if user and user["settings"] then
    settings["original_user_settings"] = deepcopy(user["settings"])
    deep_merge_overwrite_arrays(settings, settings["original_user_settings"])
  end
end
