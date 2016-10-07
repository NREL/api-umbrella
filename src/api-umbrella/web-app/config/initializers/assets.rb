# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '1.0'

# Add additional assets to the asset load path
# Rails.application.config.assets.paths << Emoji.images_path

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in app/assets folder are already added.
Rails.application.config.assets.precompile += [
  "admin/login.css",
  "admin/server_side_loader.js",
]

# Move default assets directory so this project can co-exist with the
# static-site projectt that delivers most of the web content.
Rails.application.config.assets.prefix = "/web-assets"

# Generate non-cached busted versions of assets that the admin-ui app needs to
# link directly to (since it has no knowledge of the cache-busted URLs). We
# just need to make sure these assets aren't allowed to be cached by the
# browser.
#
# This is used for sharing i18n data between the Rails and Ember app. While not
# the most optimized solution, it should be fine for sharing this bit of data.
NonStupidDigestAssets.whitelist += [
  "admin/server_side_loader.js",
]
