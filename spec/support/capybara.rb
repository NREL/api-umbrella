require "capybara/rspec"
require "capybara/rails"
require "capybara/poltergeist"

Capybara.register_driver :poltergeist do |app|
  Capybara::Poltergeist::Driver.new(app, {
    :phantomjs_logger => File.open("#{Rails.root}/log/test_phantomjs.log", "a"),
  })
end

Capybara.javascript_driver = :poltergeist
