source "https://rubygems.org"
source "https://rails-assets.org"

gem "rails", "~> 3.2.21"

# Rails app server
gem "puma", "~> 2.9.0"

# Error notification service (optional)
gem "rollbar", "~> 1.2.9", :require => false

# Environment specific configuration
gem "dotenv-rails", "~> 1.0.1"

# Abort requests that take too long
gem "rack-timeout", "~> 0.0.4"

# For proxying HTTP requests to password-protected places for admins.
gem "rack-proxy", "~> 0.5.16"

# JSON handling
gem "multi_json", "~> 1.10.1"
gem "oj", "~> 2.10.3", :platforms => [:ruby]
gem "oj_mimic_json", "~> 1.0.1", :platforms => [:ruby]

# MongoDB
gem "mongoid", "~> 3.1.6"

# Created/updated userstamping
gem "mongoid_userstamp", "~> 0.3.2"

# Versioning for mongoid
gem "mongoid_delorean", "~> 1.3.0"

# Display deeply nested validation errors on embedded documents.
gem "mongoid-embedded-errors", "~> 2.0.1"

# Data migrations
gem "mongoid_rails_migrations", "~> 1.0.1"

# Orderable database items
gem "mongoid_orderable", "~> 4.1.0"

# Generate UUIDs
gem "uuidtools", "~> 2.1.4"

# Database seeding
# This branch adds mongoid compatibility:
# https://github.com/mbleigh/seed-fu/pull/80
gem "seed-fu", :git => "https://github.com/GUI/seed-fu.git", :branch => "mongoid"

# Elasticsearch
gem "elasticsearch", "~> 1.0.4"

# OmniAuth-based authentication
gem "devise", "~> 3.4.0"
gem "omniauth", "~> 1.2.1"
gem "omniauth-cas", "~> 1.1.0"
gem "omniauth-facebook", "~> 2.0.0"
gem "omniauth-github", "~> 1.1.2"
gem "omniauth-google-oauth2", "~> 0.2.2"
gem "omniauth-myusa", :git => "https://github.com/GSA-OCSIT/omniauth-myusa.git"
gem "omniauth-persona", "~> 0.0.1"
gem "omniauth-twitter", "~> 1.0.1"

# Authorization
gem "pundit", "~> 0.3.0"

# Pagination
gem "kaminari", "~> 0.16.1"
gem "kaminari-bootstrap", "~> 0.1.3"

# Navigation links
gem "tabs_on_rails", "~> 2.2.0"

# Unobtrusive javascript for Rails helpers (things like delete links).
gem "jquery-rails", "~> 3.1.0"

# Views/templates for APIs
gem "rabl", "~> 0.11.0"
gem "jbuilder", "~> 2.2.2"
gem "csv_builder", "~> 2.1.1"

# Country and state name lookups
gem "countries", "~> 0.9.3"

# Ember.js
gem "ember-rails", "~> 0.15.0"
gem "ember-source", "~> 1.7.0"

# HTML diffs
gem "diffy", "~> 3.0.3"

# Use a newer version of Psych for YAML. The newer gem version does a better
# job of making multi-line strings and strings with colons in them more human
# readable.
gem "psych", "~> 2.0.5", :platforms => [:ruby]

# For user-inputted YAML.
gem "safe_yaml", "~> 1.0.4", :require => "safe_yaml/load"

# YAML configuration files.
gem "rails_config", "~> 0.4.2"

# Delayed jobs and background tasks
gem "delayed_job_mongoid", "~> 2.1.0"
gem "daemons", "~> 1.1.9"

# HTML email styling
gem "premailer-rails", "~> 1.8.0"

group :production, :staging do
  # Log to stdout instead of file
  gem "rails_stdout_logging", "~> 0.0.3"
end

# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'sass-rails', '~> 3.2.6'

  # Hold at sass 3.2, since newer versions lead to weird sprockets errors.
  # Apparently fixed in newer versions of sprockets, but not the version Rails
  # 3.2 uses:
  # https://github.com/sass/sass/issues/1144
  gem "sass", "~> 3.2.19"

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
  # This specific version contains the CLEAN_EXPIRED_ASSETS option to speed up
  # deployments by combining two tasks into one (particularly under JRuby).
  gem "turbo-sprockets-rails3", "0.3.13"

  # Client-side translations
  gem "rails-assets-polyglot", "~> 0.4.1"

  # Smooth scrolling to content
  gem "rails-assets-jquery.scrollTo", "~> 1.4.14"

  # Icons
  gem "rails-assets-fontawesome", "~> 4.2.0"

  # Code editor (for syntax highlighting inside textareas)
  gem "rails-assets-ace-builds", "~> 1.1.7"

  # Visual text diffs
  gem "rails-assets-jsdiff", "~> 1.0.8"

  # jQuery ajax calls wrapped in Ember promises
  gem "rails-assets-ic-ajax", "~> 2.0.1"

  gem "rails-assets-bootbox", "~> 3.3.0"
  gem "rails-assets-bootstrap-daterangepicker", "~> 1.3.12"
  gem "rails-assets-datatables", "~> 1.10.2"
  gem "rails-assets-html5shiv", "~> 3.7.0"
  gem "rails-assets-inflection", "~> 1.4.0"
  gem "rails-assets-jquery", "~> 1.11.0"
  gem "rails-assets-jquery-bbq-deparam", "~> 1.2.1"
  gem "rails-assets-jstz-detect", "~> 1.0.5"
  gem "rails-assets-livestampjs", "~> 1.1.2"
  gem "rails-assets-lodash", "~> 2.4.1"
  gem "rails-assets-moment", "~> 2.8.2"
  gem "rails-assets-numeral", "~> 1.5.3"
  gem "rails-assets-pnotify", "~> 2.0.1"
  gem "rails-assets-qtip2", "~> 2.2.0"
  gem "rails-assets-selectize", "~> 0.11.2"
  gem "rails-assets-spinjs", "~> 2.0.0"
end

# Bundle gems for the local environment. Make sure to
# put test-only gems in this group so their generators
# and rake tasks are available in development mode:
group :development, :test do
  gem "rspec-rails", "~> 2.99.0"
  gem "factory_girl_rails", "~> 4.4.1"
  gem "rspec-html-matchers", "~> 0.5.0"

  # Rspec formatter - Prints overall progress and error details as they happen.
  gem "fuubar", "~> 1.3.3"

  # Ruby lint/style checker
  gem "rubocop", "~> 0.26.1", :require => false

  # Code coverage testing
  gem "coveralls", "~> 0.7.0", :require => false

  # Real browser testing
  gem "capybara", "~> 2.4.3"

  # Headless webkit for capybara
  gem "poltergeist", "~> 1.5.0"

  # Clean the database between tests
  gem "database_cleaner", "~> 1.3.0"

  # JavaScript lint/style checker
  # This git fork contains a newer version of the underlying jshint library.
  gem "jshintrb", "~> 0.2.4", :git => "https://github.com/Paxa/jshintrb.git"

  # For testing drag and drop in capybara.
  gem "rails-assets-jquery-simulate-ext", "~> 1.3.0"
end

group :development do
  # Deployment
  gem "capistrano", "~> 3.2.1"
  gem "capistrano-rails", "~> 1.1.1"

  gem "awesome_print", "~> 1.2.0"
end
