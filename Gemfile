source "https://rubygems.org"

gem "rails", "~> 3.2.17"

# Environment specific configuration
gem "dotenv-rails", "~> 0.9.0"

# Rails app server
gem "torquebox", "~> 3.0.1", :platforms => [:jruby]

# Abort requests that take too long
gem "rack-timeout", "~> 0.0.4"

# MongoDB
gem "mongoid", "~> 3.1.5"

# Structure trees of mongoid documents
gem "mongoid-tree", "~> 1.0.4", :require => "mongoid/tree"

# Created/updated userstamping
gem "mongoid_userstamp", "~> 0.3.0"

# Versioning for mongoid
# This git branch fixes embeds_one functionality.
gem "mongoid_delorean", "~> 1.1.1", :git => "https://github.com/GUI/mongoid_delorean.git"

# Display deeply nested validation errors on embedded documents.
gem "mongoid-embedded-errors", "~> 2.0.1"

# Data migrations
gem "mongoid_rails_migrations", "~> 1.0.1"

# Data migrations
gem "mongoid_orderable", "~> 4.1.0"

# Generate UUIDs
gem "uuidtools", "~> 2.1.4"

# Database seeding
gem "seed-fu", "~> 2.3.0"

# Elasticsearch
gem "stretcher", "~> 1.21.1"

# OmniAuth-based authentication
gem "devise", "~> 3.2.2"
gem "omniauth", "~> 1.1.4"
gem "omniauth-google-oauth2", "~> 0.2.1"
gem "omniauth-persona", "~> 0.0.1"

# Form layout and display
gem "simple_form", "~> 2.1.0"

# Pagination
gem "kaminari", "~> 0.15.0"
gem "kaminari-bootstrap", "~> 0.1.3"

# Navigation links
gem "tabs_on_rails", "~> 2.2.0"

# Unobtrusive javascript for Rails helpers (things like delete links).
gem "jquery-rails", "~> 3.0.4"

# Breadcrumbs
gem "crummy", "~> 1.8.0"

gem "client_side_validations", "~> 3.2.6"
gem "client_side_validations-simple_form", "~> 2.1.0"

gem "nokogiri", "~> 1.6.0"

# For creating friendly URL slugs.
gem "babosa", "~> 0.3.11"

# For running the python pygmentize program
gem "childprocess", "~> 0.3.9"

# Views/templates for APIs
gem "rabl", "~> 0.9.2"
gem "csv_builder", "~> 2.1.1"

# Country and state name lookups
gem "countries", "~> 0.9.3"

# Custom YAML config files
gem "settingslogic", "~> 2.0.9"

# Ember.js
gem "ember-rails", "~> 0.14.0"
gem "ember-source", "~> 1.1.2"

# HTML diffs
gem "diffy", "~> 3.0.1"

# Use a newer version of Psych for YAML. The newer gem version does a better
# job of making multi-line strings and strings with colons in them more human
# readable.
gem "psych", "~> 2.0.1", :platforms => [:ruby]

# For user-inputted YAML.
# Use version from git so it doesn't automatically monkey-patch.
gem "safe_yaml", :git => "https://github.com/dtao/safe_yaml.git", :require => "safe_yaml/load"

# Environment-specific configuration files.
gem "rails_config", "~> 0.3.3"

# Delayed jobs and background tasks
gem "delayed_job_mongoid", "~> 2.0.0"
gem "daemons", "~> 1.1.9"

# HTML email styling
gem "premailer-rails", "~> 1.7.0"

# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'sass-rails', '~> 3.2.6'

  # A Sass version of Twitter Bootstrap. This it the basis for our styles and
  # JavaScript components.
  gem "bootstrap-sass", "~> 2.3.2.2"

  # Sass utilities and automatic image spirtes
  gem "compass-rails", "~> 1.0.3"

  # See https://github.com/sstephenson/execjs#readme for more supported runtimes
  gem 'therubyracer', "~> 0.12.0", :platforms => :ruby
  # For JRuby, use the Node.js execjs runtime - We'll assume it's on the
  # servers so it gets picked up by execjs. It's faster than therubyrhino.

  # JavaScript compression
  gem 'uglifier', "~> 2.3.1"

  # Smarter handling of compiled CSS with relative paths (like Jammit)
  gem "sprockets-urlrewriter", "~> 0.1.2"

  # Faster asset precompilation and caching.
  #
  # This fork allows cleaning expired assets at the same time as precompiling,
  # so two rake tasks aren't necessary during our cap deploys. This saves
  # significant time under JRuby. Hopefully it'll be merged into the main gem.
  gem "turbo-sprockets-rails3", :git => "https://github.com/GUI/turbo-sprockets-rails3.git"

  # Improve PNG speed for image sprite generation
  gem "oily_png", "~> 1.1.0", :platforms => [:ruby]
end

# Bundle gems for the local environment. Make sure to
# put test-only gems in this group so their generators
# and rake tasks are available in development mode:
group :development, :test do
  gem "rspec-rails", "~> 2.14.0"
  gem "factory_girl_rails", "~> 4.3.0"
  gem "rspec-html-matchers", "~> 0.4.3"

  # Ruby lint/style checker
  gem "rubocop", "~> 0.15.0"

  # Code coverage testing
  gem "coveralls", "~> 0.7.0", :require => false

  # Real browser testing
  gem "capybara", "~> 2.1.0"

  # Headless webkit for capybara
  gem "poltergeist", "~> 1.4.1"
end

group :development do
  # Deployment
  gem "capistrano", "~> 2.15.5"
  gem "capistrano-ext", "~> 1.2.1"
  gem "capistrano_nrel_ext", :git => "https://github.com/NREL/capistrano_nrel_ext.git"

  gem "torquebox-server", "~> 3.0.1", :platforms => [:jruby]

  gem "yajl-ruby", "~> 1.1.0", :require => false, :platforms => [:ruby]
  gem "oj", "~> 2.2.3", :require => false, :platforms => [:ruby]

  gem "awesome_print", "~> 1.2.0"

  gem "yard", "~> 0.8.7", :require => false
  gem "kramdown", "~> 1.2.0", :require => false
end
