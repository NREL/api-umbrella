# Be sure to restart your server when you modify this file.

ApiUmbrella::Application.config.session_store(:cookie_store, {
  :key => "_api_umbrella_session",

  # Don't allow cookies to be accessed by javascript.
  :httponly => true,

  # Use secure cookies to prevent sidejacking.
  :secure => !["development", "test"].include?(Rails.env),
})

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rails generate session_migration")
# ApiUmbrella::Application.config.session_store :active_record_store
