###
# Compass
###

# Change Compass configuration
# compass_config do |config|
#   config.output_style = :compact
# end

###
# Page options, layouts, aliases and proxies
###

# Per-page layout changes:
#
# With no layout
# page "/path/to/file.html", :layout => false
#
# With alternative layout
# page "/path/to/file.html", :layout => :otherlayout
#
# A path which all have the same layout

# Proxy pages (http://middlemanapp.com/basics/dynamic-pages/)
# proxy "/this-page-has-no-template.html", "/template-file.html", :locals => {
#  :which_fake_page => "Rendering a fake page with a local variable" }

###
# Helpers
###

# Automatic image dimensions on image_tag helper
# activate :automatic_image_sizes

# Reload the browser automatically whenever files change
activate :livereload

# Methods defined in the helpers block are available in templates
# helpers do
#   def some_helper
#     "Helping"
#   end
# end

set :css_dir, 'stylesheets'

set :js_dir, 'javascripts'

set :images_dir, 'images'

# Build-specific configuration
configure :build do
  # For example, change the Compass output style for deployment
  activate :minify_css

  # Minify Javascript on build
  activate :minify_javascript

  # Enable cache buster
  activate :asset_hash

  # Use relative URLs
  activate :relative_assets
  set :relative_links, true

  # Or use a different image path
  # set :http_prefix, "/Content/images/"
end

activate :directory_indexes

set :markdown_engine, :kramdown
set :markdown, {
  :input => 'GFM',
  :smart_quotes => ['apos', 'apos', 'quot', 'quot'],
}

ignore "chef/*"
ignore "workspace/*"

redirect "docs/admin-api.html", :to => "https://api-umbrella.readthedocs.org/en/latest/"
redirect "docs/admin-customize-public-website.html", :to => "https://api-umbrella.readthedocs.org/en/latest/"
redirect "docs/api-keys.html", :to => "https://api-umbrella.readthedocs.org/en/latest/"
redirect "docs/api-scopes.html", :to => "https://api-umbrella.readthedocs.org/en/latest/"
redirect "docs/architecture.html", :to => "https://api-umbrella.readthedocs.org/en/latest/"
redirect "docs/backend-headers.html", :to => "https://api-umbrella.readthedocs.org/en/latest/"
redirect "docs/caching.html", :to => "https://api-umbrella.readthedocs.org/en/latest/"
redirect "docs/deployment.html", :to => "https://api-umbrella.readthedocs.org/en/latest/"
redirect "docs/development-setup.html", :to => "https://api-umbrella.readthedocs.org/en/latest/"
redirect "docs/getting-started.html", :to => "https://api-umbrella.readthedocs.org/en/latest/"
redirect "docs/index.html", :to => "https://api-umbrella.readthedocs.org/en/latest/"
redirect "docs/smtp-configuration.html", :to => "https://api-umbrella.readthedocs.org/en/latest/"
redirect "download.html", :to => "install.html"
