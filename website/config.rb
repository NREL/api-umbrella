# Activate and configure extensions
# https://middlemanapp.com/advanced/configuration/#configuring-extensions

# activate :autoprefixer do |prefix|
#   prefix.browsers = "last 2 versions"
# end

# Layouts
# https://middlemanapp.com/basics/layouts/

# Per-page layout changes
page '/*.xml', :layout => false
page '/*.json', :layout => false
page '/*.txt', :layout => false

# With alternative layout
# page '/path/to/file.html', layout: 'other_layout'

# Proxy pages
# https://middlemanapp.com/advanced/dynamic-pages/

# proxy(
#   '/this-page-has-no-template.html',
#   '/template-file.html',
#   locals: {
#     which_fake_page: 'Rendering a fake page with a local variable'
#   },
# )

# Helpers
# Methods defined in the helpers block are available in templates
# https://middlemanapp.com/basics/helper-methods/

# helpers do
#   def some_helper
#     'Helping'
#   end
# end

# Build-specific configuration
# https://middlemanapp.com/advanced/configuration/#environment-specific-settings

# configure :build do
#   activate :minify_css
#   activate :minify_javascript
# end

set :css_dir, 'stylesheets'
set :js_dir, 'javascripts'
set :fonts_dir, 'fonts'
set :images_dir, 'images'

# Build-specific configuration
configure :build do
  # For example, change the Compass output style for deployment
  activate :minify_css

  # Minify Javascript on build
  activate :minify_javascript

  # Enable cache buster
  activate :asset_hash

  # Or use a different image path
  # set :http_prefix, "/Content/images/"
end

# Use relative URLs
activate :relative_assets
set :relative_links, true

activate :sprockets
activate :directory_indexes

set :markdown_engine, :kramdown
set :markdown, {
  :input => 'GFM',
  :smart_quotes => ['apos', 'apos', 'quot', 'quot'],
}

redirect "docs/admin-api.html", :to => "https://api-umbrella.readthedocs.org/en/latest/admin/api.html"
redirect "docs/admin-customize-public-website.html", :to => "https://api-umbrella.readthedocs.org/en/latest/"
redirect "docs/api-keys.html", :to => "https://api-umbrella.readthedocs.org/en/latest/api-consumer/api-key-usage.html"
redirect "docs/api-scopes.html", :to => "https://api-umbrella.readthedocs.org/en/latest/admin/admin-accounts/permissions.html"
redirect "docs/architecture.html", :to => "https://api-umbrella.readthedocs.org/en/latest/developer/architecture.html"
redirect "docs/backend-headers.html", :to => "https://api-umbrella.readthedocs.org/en/latest/admin/api-backends/http-headers.html"
redirect "docs/caching.html", :to => "https://api-umbrella.readthedocs.org/en/latest/admin/api-backends/caching.html"
redirect "docs/deployment.html", :to => "https://api-umbrella.readthedocs.org/en/latest/developer/deploying.html"
redirect "docs/development-setup.html", :to => "https://api-umbrella.readthedocs.org/en/latest/developer/dev-setup.html"
redirect "docs/getting-started.html", :to => "https://api-umbrella.readthedocs.org/en/latest/getting-started.html"
redirect "docs/index.html", :to => "https://api-umbrella.readthedocs.org/en/latest/"
redirect "docs/smtp-configuration.html", :to => "https://api-umbrella.readthedocs.org/en/latest/server/smtp-config.html"
redirect "download.html", :to => "https://api-umbrella.readthedocs.org/en/latest/getting-started.html"
