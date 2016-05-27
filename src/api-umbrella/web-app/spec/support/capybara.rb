require "capybara/rspec"
require "capybara/rails"
require "capybara/poltergeist"
require "capybara-screenshot/rspec"

Capybara.register_driver :poltergeist do |app|
  Capybara::Poltergeist::Driver.new(app, {
    :phantomjs_logger => File.open("#{Rails.root}/log/test_phantomjs.log", "a"),
  })
end

Capybara.javascript_driver = :poltergeist

# Set a longer timeout for places like TravisCI where things can sometimes be
# slower.
Capybara.default_max_wait_time = 15

module CapybaraFeatureHelpers
  def wait_for_ajax
    Timeout.timeout(Capybara.default_max_wait_time) do
      loop until finished_all_ajax_requests?
    end
  end

  def finished_all_ajax_requests?
    page.evaluate_script('jQuery.active').zero?
  end

  def wait_for_datatables_filter
    sleep 1
  end

  def wait_for_loading_spinners
    page.should_not have_selector(".loading-overlay .spinner")
    page.should_not have_selector(".dataTables_wrapper .blockOverlay")
    page.should_not have_selector(".dataTables_wrapper .blockMsg")
  end

  def wait_until
    require "timeout"
    Timeout.timeout(Capybara.default_max_wait_time) do
      sleep(0.1) until(value = yield) # rubocop:disable Lint/AssignmentInCondition
      value
    end
  end

  def delay_all_ajax_calls(delay = 1500)
    page.execute_script <<-eos
      $.ajaxOrig = $.ajax;
      $.ajax = function() {
        var args = arguments;
        var self = this;
        setTimeout(function() {
          $.ajaxOrig.apply(self, args);
        }, #{delay});
      };
    eos
  end
end

RSpec.configure do |config|
  config.include CapybaraFeatureHelpers, :type => :feature

  config.before(:each, :type => :feature) do
    # Set the default language for tests to US English.
    #
    # This ensures we have a consistent baseline for testing, regardless of the
    # default language on the computer running tests. See:
    # https://github.com/NREL/api-umbrella/issues/242
    #
    # We then explicitly test the support of other languages by overriding this
    # in spec/features/admin/locales_spec.rb
    page.driver.add_headers("Accept-Language" => "en-US")
  end
end
