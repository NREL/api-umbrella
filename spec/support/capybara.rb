require "capybara/rspec"
require "capybara/rails"
require "capybara/poltergeist"

Capybara.register_driver :poltergeist do |app|
  Capybara::Poltergeist::Driver.new(app, {
    :phantomjs_logger => File.open("#{Rails.root}/log/test_phantomjs.log", "a"),
  })
end

Capybara.javascript_driver = :poltergeist

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
end

RSpec.configure do |config|
  config.include CapybaraFeatureHelpers, :type => :feature
end
