require "capybara/rspec"
require "capybara/rails"
require "capybara/poltergeist"

Capybara.register_driver :poltergeist do |app|
  Capybara::Poltergeist::Driver.new(app, {
    :phantomjs_logger => File.open("#{Rails.root}/log/test_phantomjs.log", "a"),
  })
end

Capybara.javascript_driver = :poltergeist

# Set a longer timeout for places like TravisCI where things can sometimes be
# slower.
Capybara.default_wait_time = 15

module CapybaraFeatureHelpers
  def wait_for_ajax
    Timeout.timeout(Capybara.default_wait_time) do
      loop until finished_all_ajax_requests?
    end
  end

  def finished_all_ajax_requests?
    page.evaluate_script('jQuery.active').zero?
  end

  def wait_for_datatables_filter
    sleep 1
  end

  def wait_until
    require "timeout"
    Timeout.timeout(Capybara.default_wait_time) do
      sleep(0.1) until(value = yield) # rubocop:disable Lint/AssignmentInCondition
      value
    end
  end
end

RSpec.configure do |config|
  config.include CapybaraFeatureHelpers, :type => :feature
end
