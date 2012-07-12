source "http://gems.cttsdev.nrel.gov"
source :rubygems

gem "rails", "~> 3.2.6"

# Deployment
gem "capistrano-ext"
gem "capistrano_nrel_ext", "~> 0.2.10"

# MongoDB
gem "mongoid"

# Lock the BSON version dependency, since the 1.3 branch didn't do this.
gem "bson", "~> 1.3.1"
gem "bson_ext", "~> 1.3.1"

# Structure trees of mongoid documents
gem "mongoid-tree", :require => "mongoid/tree"

# Database seeding
gem "seed-fu"

# CAS-based authentication
gem "devise"
gem "omniauth-cas"

# Form layout and display
gem "simple_form"

# Pagination
gem "kaminari"

# Navigation links
gem "tabs_on_rails"

# Sass stylesheets and automatic image spirtes
gem "compass-rails"

# Improve PNG speed for image sprite generation
gem "oily_png"

# Unobtrusive javascript for Rails helpers (things like delete links).
gem "jquery-rails"

gem "crummy"

#gem "client_side_validations", "~> 3.2.0.beta"
gem "client_side_validations-simple_form", "~> 1.5.0.beta"
gem "client_side_validations", :git => "http://github.com/bcardarella/client_side_validations.git"

gem "nokogiri"
gem "babosa"
gem "albino"

# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'sass-rails',   '~> 3.2.3'
  gem 'coffee-rails', '~> 3.2.1'

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
end

group :development do
  # Deployment
  gem "capistrano-ext"
  gem "capistrano_nrel_ext"

  gem "yajl-ruby", :require => false

  gem "yard", :require => false
  gem "kramdown", :require => false
end
