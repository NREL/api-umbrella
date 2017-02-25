require "serverspec"

# Wipe the bundler environment variables, so they don't propagate down to the
# various api-umbrella restart commands the tests run (otherwise, the
# api-umbrella processes might try to use this verify bundle for starting the
# web app).
#
# Note: This shouldn't be necessary once we're only testing upgrades from
# packages v0.14.0+ since v0.14.0+ handles stripping other bundler environments
# directly inside the api-umbrella startup script. But since we're still
# testing upgrades from older package versions, keep this around.
ENV.delete("BUNDLE_GEMFILE")
ENV.delete("BUNDLE_APP_CONFIG")
ENV.delete("RUBYLIB")
ENV.delete("BUNDLER_VERSION")

set :backend, :exec
