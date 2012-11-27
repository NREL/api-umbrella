# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'api-umbrella-gatekeeper/version'

Gem::Specification.new do |gem|
  gem.name          = "api-umbrella-gatekeeper"
  gem.version       = ApiUmbrella::Gatekeeper::VERSION
  gem.authors       = ["Nick Muerdter"]
  gem.email         = ["nick.muerdter@nrel.gov"]
  gem.description   = %q{A custom reverse proxy to control access to your APIs. Performs API key validation, request rate limiting, and gathers analytics.}
  gem.summary       = %q{A custom reverse proxy to control access to your APIs.}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib", "app/models"]

  # Run everything through the EventMachine proxy.
  gem.add_dependency("em-proxy")
  gem.add_dependency("eventmachine", ">= 1.0.0")

  # For some of activesupport's niceties, like `blank?`
  gem.add_dependency("activesupport", "~> 3.2.7")

  # MongoDB
  gem.add_dependency("mongoid", ">= 3.0.0")

  # Rack for contructing our proxy using modularized middlewares.
  gem.add_dependency("rack")

  # rack-throttle and redis for rate limiting. Use hiredis for better
  # performance.
  gem.add_dependency("rack-throttle")
  gem.add_dependency("hiredis")
  gem.add_dependency("redis")

  # For parsing the raw HTTP requests.
  gem.add_dependency("http_parser.rb")

  # For generating raw HTTP responses.
  gem.add_dependency("thin")

  # Yajl for JSON encoding.
  gem.add_dependency("yajl-ruby")

  gem.add_dependency("trollop")

  gem.add_development_dependency("rake")
  gem.add_development_dependency("rspec")

  # For building objects.
  gem.add_development_dependency("factory_girl")

  # For clearing the database between tests.
  gem.add_development_dependency("database_cleaner")

  # For simulating calls to our Rack middleware.
  gem.add_development_dependency("rack-test")

  # For validating Time.now usage.
  gem.add_development_dependency("timecop")

  # For validating XML.
  gem.add_development_dependency("nokogiri")
end
