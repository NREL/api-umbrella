source "https://rubygems.org"
source "https://rails-assets.org"

gem "rails", "~> 3.2.19"

# Rails app server
gem "puma", "~> 2.9.0"

# Environment specific configuration
gem "dotenv-rails", "~> 0.11.1"

# Abort requests that take too long
gem "rack-timeout", "~> 0.0.4"

# JSON handling
gem "multi_json", "~> 1.10.1"
gem "oj", "~> 2.10.0", :platforms => [:ruby]

# MongoDB
gem "mongoid", "~> 3.1.6"

# Structure trees of mongoid documents
gem "mongoid-tree", "~> 1.0.4", :require => "mongoid/tree"

# Created/updated userstamping
gem "mongoid_userstamp", "~> 0.3.2"

# Versioning for mongoid
# This git branch fixes embeds_one functionality.
gem "mongoid_delorean", "~> 1.2.1"

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
gem "elasticsearch", "~> 1.0.4"

# OmniAuth-based authentication
gem "devise", "~> 3.2.4"
gem "omniauth", "~> 1.2.1"
gem "omniauth-google-oauth2", "~> 0.2.2"
gem "omniauth-persona", "~> 0.0.1"

# Form layout and display
gem "simple_form", "~> 2.1.1"

# Pagination
gem "kaminari", "~> 0.15.1"
gem "kaminari-bootstrap", "~> 0.1.3"

# Navigation links
gem "tabs_on_rails", "~> 2.2.0"

# Unobtrusive javascript for Rails helpers (things like delete links).
gem "jquery-rails", "~> 3.1.0"

# Breadcrumbs
gem "crummy", "~> 1.8.0"

gem "client_side_validations", "~> 3.2.6"
gem "client_side_validations-simple_form", "~> 2.1.0"

# For creating friendly URL slugs.
gem "babosa", "~> 0.3.11"

# For running the python pygmentize program
gem "childprocess", "~> 0.5.1"

# Views/templates for APIs
gem "rabl", "~> 0.10.1"
gem "csv_builder", "~> 2.1.1"

# Country and state name lookups
gem "countries", "~> 0.9.3"

# Custom YAML config files
gem "settingslogic", "~> 2.0.9"

# Ember.js
gem "ember-rails", "~> 0.14.1"
gem "ember-source", "~> 1.4.0"

# HTML diffs
gem "diffy", "~> 3.0.3"

# Use a newer version of Psych for YAML. The newer gem version does a better
# job of making multi-line strings and strings with colons in them more human
# readable.
gem "psych", "~> 2.0.5", :platforms => [:ruby]

# For user-inputted YAML.
# Use version from git so it doesn't automatically monkey-patch.
gem "safe_yaml", "~> 1.0.1", :require => "safe_yaml/load"

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
  gem "compass-rails", "~> 1.1.7"

  # See https://github.com/sstephenson/execjs#readme for more supported runtimes
  gem 'therubyracer', "~> 0.12.1", :platforms => :ruby
  # For JRuby, use the Node.js execjs runtime - We'll assume it's on the
  # servers so it gets picked up by execjs. It's faster than therubyrhino.

  # JavaScript compression
  gem 'uglifier', "~> 2.5.0"

  # Smarter handling of compiled CSS with relative paths (like Jammit)
  gem "sprockets-urlrewriter", "~> 0.1.2"

  # Faster asset precompilation and caching.
  #
  # This fork allows cleaning expired assets at the same time as precompiling,
  # so two rake tasks aren't necessary during our cap deploys. This saves
  # significant time under JRuby. Hopefully it'll be merged into the main gem.
  gem "turbo-sprockets-rails3", :git => "https://github.com/GUI/turbo-sprockets-rails3.git"

  gem "rails-assets-bootbox", "~> 3.3.0"
  gem "rails-assets-bootstrap-daterangepicker", "~> 1.3.11"
  gem "rails-assets-ember-model", "~> 0.0.11"
  gem "rails-assets-html5shiv", "~> 3.7.0"
  gem "rails-assets-inflection", "~> 1.3.5"
  gem "rails-assets-jquery", "~> 1.11.0"
  gem "rails-assets-jquery-bbq-deparam", "~> 1.2.1"
  gem "rails-assets-jstz-detect", "~> 1.0.5"
  gem "rails-assets-livestampjs", "~> 1.1.2"
  gem "rails-assets-lodash", "~> 2.4.1"
  gem "rails-assets-moment", "~> 2.8.1"
  gem "rails-assets-numeral", "~> 1.5.3"
  gem "rails-assets-pnotify", "~> 1.3.1"
  gem "rails-assets-qtip2", "~> 2.2.0"
  gem "rails-assets-selectize", "~> 0.11.0"
  gem "rails-assets-spinjs", "~> 2.0.0"
end

# Bundle gems for the local environment. Make sure to
# put test-only gems in this group so their generators
# and rake tasks are available in development mode:
group :development, :test do
  gem "rspec-rails", "~> 2.99.0"
  gem "factory_girl_rails", "~> 4.4.1"
  gem "rspec-html-matchers", "~> 0.5.0"

  # Ruby lint/style checker
  gem "rubocop", "~> 0.25.0"

  # Code coverage testing
  gem "coveralls", "~> 0.7.0", :require => false

  # Real browser testing
  gem "capybara", "~> 2.4.1"

  # Headless webkit for capybara
  gem "poltergeist", "~> 1.5.0"

  # Clean the database between tests
  gem "database_cleaner", "~> 1.3.0"
end

group :development do
  # Deployment
  gem "capistrano_nrel_ext", :git => "https://github.com/NREL/capistrano_nrel_ext.git"

  gem "awesome_print", "~> 1.2.0"
end
