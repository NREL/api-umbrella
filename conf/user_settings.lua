local moses = require "moses"
local inspect = require "inspect"
local utils = require "utils"
local stringx = require "pl.stringx"
local tablex = require "pl.tablex"
local inspect = require "inspect"

return function(settings, user)
  settings["original_api_settings"] = tablex.deepcopy(settings)

  if user and user["settings"] then
    settings["original_user_settings"] = tablex.deepcopy(user["settings"])
    utils.deep_merge_overwrite_arrays(settings, settings["original_user_settings"])
  end
end
