source :rubygems

gem "rails", "~> 3.2.6"

# MongoDB
gem "mongoid", ">= 3.0.0"

# Structure trees of mongoid documents
gem "mongoid-tree", :require => "mongoid/tree"

# Database seeding
gem "seed-fu"

# OmniAuth-based authentication
gem "devise"
gem "omniauth"

# Form layout and display
gem "simple_form"

# Pagination
gem "kaminari"

# Navigation links
gem "tabs_on_rails"

# Unobtrusive javascript for Rails helpers (things like delete links).
gem "jquery-rails"

gem "crummy"

gem "client_side_validations", ">= 3.2.0"
gem "client_side_validations-simple_form", ">= 2.0.0"

gem "nokogiri"
gem "babosa"
gem "albino"

# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'sass-rails',   '~> 3.2.3'

  # A Sass version of Twitter Bootstrap. This it the basis for our styles and
  # JavaScript components.
  gem "bootstrap-sass"

  # Sass utilities and automatic image spirtes
  gem "compass-rails"

  # See https://github.com/sstephenson/execjs#readme for more supported runtimes
  gem 'therubyracer', :platforms => :ruby

  # JavaScript compression
  gem 'uglifier'

  # CSS compression
  gem "yui-compressor"

  # Smarter handling of compiled CSS with relative paths (like Jammit)
  gem "sprockets-urlrewriter"

  # Improve PNG speed for image sprite generation
  gem "oily_png"
end

# Bundle gems for the local environment. Make sure to
# put test-only gems in this group so their generators
# and rake tasks are available in development mode:
group :development, :test do
  gem "rspec-rails"
  gem "factory_girl_rails"
  gem "rspec-html-matchers"
end

group :development do
  # Deployment
  gem "capistrano-ext"
  gem "capistrano_nrel_ext", :git => "http://github.com/NREL/capistrano_nrel_ext.git"

  gem "yajl-ruby", :require => false

  gem "awesome_print"

  gem "yard", :require => false
  gem "kramdown", :require => false
end
