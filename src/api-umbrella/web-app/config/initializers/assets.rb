# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '1.0'

# Add additional assets to the asset load path
# Rails.application.config.assets.paths << Emoji.images_path

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in app/assets folder are already added.
Rails.application.config.assets.precompile += [
  "admin/login.css",
]

# Move default assets directory so this project can co-exist with the
# static-site projectt that delivers most of the web content.
Rails.application.config.assets.prefix = "/web-assets"
