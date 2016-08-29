# Be sure to restart your server when you modify this file.

Rails.application.config.session_store(:cookie_store, {
  :key => "_api_umbrella_session",

  # Don't allow cookies to be accessed by javascript.
  :httponly => true,

  # Use secure cookies to prevent sidejacking.
  :secure => !["development", "test"].include?(Rails.env),
})
