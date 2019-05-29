return function(strategy_name, path)
  local url_name = strategy_name
  if strategy_name == "google" then
    url_name = "google_oauth2"
  end

  return "/admins/auth/" .. url_name .. path
end

