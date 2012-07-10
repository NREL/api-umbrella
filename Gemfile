source "http://gems.cttsdev.nrel.gov"
source :rubygems

gem "rails", "~> 3.0.10"

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
gem "oa-enterprise", ">= 0.2.6"

# Form layout and display
gem "simple_form"

# Pagination
gem "kaminari"

# Navigation links
gem "tabs_on_rails"

# Sass stylesheets and automatic image spirtes
gem "compass"

# Improve PNG speed for image sprite generation
gem "oily_png"

# Asset packaging and compression
gem "jammit"

# Unobtrusive javascript for Rails helpers (things like delete links).
gem "jquery-rails"

gem "crummy"

gem "client_side_validations"

gem "nokogiri"
gem "babosa"
gem "albino"

# Bundle gems for the local environment. Make sure to
# put test-only gems in this group so their generators
# and rake tasks are available in development mode:
group :development, :test do
  gem "rspec-rails"
  gem "factory_girl_rails"
end

group :development do
  gem "yajl-ruby", :require => false

  gem "yard", :require => false
  gem "kramdown", :require => false
end
