source :rubygems

gem "rails", "~> 3.2.14"

# Environment specific configuration
gem "dotenv-rails"

# Rails app server
gem "torquebox", "~> 3.0.0", :platforms => [:jruby]

# Abort requests that take too long
gem "rack-timeout"

# MongoDB
gem "mongoid", "~> 3.1.4"

# Structure trees of mongoid documents
gem "mongoid-tree", "~> 1.0.3", :require => "mongoid/tree"

# Created/updated userstamping 
gem "mongoid_userstamp", "~> 0.2.1"

# Versioning for mongoid
# This git branch fixes embeds_one functionality.
gem "mongoid_delorean", "~> 1.1.1", :git => "https://github.com/crafters/mongoid_delorean.git"

# Database seeding
gem "seed-fu"

# Elasticsearch
# This git branch allows access to the ruby hash for responses to improve
# performance: https://github.com/PoseBiz/stretcher/pull/70
gem "stretcher", "~> 1.21.0", :git => "https://github.com/GUI/stretcher.git", :branch => "optional-mash"

# OmniAuth-based authentication
gem "devise", "~> 3.0.3"
gem "omniauth"
gem "omniauth-google-oauth2"
gem "omniauth-persona"

# Form layout and display
gem "simple_form", "~> 2.1.0"

# Pagination
gem "kaminari"
gem "kaminari-bootstrap"

# Navigation links
gem "tabs_on_rails"

# Unobtrusive javascript for Rails helpers (things like delete links).
gem "jquery-rails", "~> 3.0.4"

# Breadcrumbs
gem "crummy", "~> 1.7.2"

gem "client_side_validations", "~> 3.2.6"
gem "client_side_validations-simple_form", "~> 2.1.0"

gem "nokogiri"

# For creating friendly URL slugs.
gem "babosa", "~> 0.3.11"

# For running the python pygmentize program
gem "childprocess"

# Views/templates for APIs
gem "rabl", "~> 0.8.6"

# Country and state name lookups
gem "countries"

# Custom YAML config files
gem "settingslogic"

# Ember.js
gem "ember-rails", "~> 0.13.0"
gem "ember-source", "~> 1.0.0"

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
  # For JRuby, use the Node.js execjs runtime - We'll assume it's on the
  # servers so it gets picked up by execjs. It's faster than therubyrhino.

  # JavaScript compression
  gem 'uglifier'

  # Smarter handling of compiled CSS with relative paths (like Jammit)
  gem "sprockets-urlrewriter"

  # Faster asset precompilation and caching.
  #
  # This fork allows cleaning expired assets at the same time as precompiling,
  # so two rake tasks aren't necessary during our cap deploys. This saves
  # significant time under JRuby. Hopefully it'll be merged into the main gem.
  gem "turbo-sprockets-rails3", :git => "https://github.com/GUI/turbo-sprockets-rails3.git"

  # Improve PNG speed for image sprite generation
  gem "oily_png", :platforms => [:ruby]

  # JavaScript Backbone extensions
  gem "marionette-rails"

  # For JavaScript templates
  #gem "handlebars_assets"
end

# Bundle gems for the local environment. Make sure to
# put test-only gems in this group so their generators
# and rake tasks are available in development mode:
group :development, :test do
  gem "rspec-rails"
  gem "factory_girl_rails"
  gem "rspec-html-matchers"

  # Real browser testing
  gem "capybara"

  # Headless webkit for capybara
  gem "poltergeist"
end

group :development do
  # Deployment
  gem "capistrano-ext"
  gem "capistrano_nrel_ext", :git => "http://github.com/NREL/capistrano_nrel_ext.git"

  gem "torquebox-server", :platforms => [:jruby]

  gem "yajl-ruby", :require => false, :platforms => [:ruby]
  gem "oj", :require => false, :platforms => [:ruby]

  gem "awesome_print"

  gem "yard", :require => false
  gem "kramdown", :require => false
end
