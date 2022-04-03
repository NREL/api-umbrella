local cache_computed_api_backend_settings = require "api-umbrella.utils.active_config_store.cache_computed_api_backend_settings"

return function(sub_settings)
  if not sub_settings then return end

  for _, sub_setting in ipairs(sub_settings) do
    if sub_setting["http_method"] then
      sub_setting["http_method"] = string.lower(sub_setting["http_method"])
    end

    if sub_setting["settings"] then
      cache_computed_api_backend_settings(sub_setting["settings"])
    else
      sub_setting["settings"] = {}
    end
  end
end
