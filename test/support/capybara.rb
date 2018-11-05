require "capybara/minitest"
require "capybara-screenshot/minitest"
require "support/api_umbrella_test_helpers/process"

def capybara_register_driver(driver_name, options = {})
  ::Capybara.register_driver(driver_name) do |app|
    root_dir = File.join(ApiUmbrellaTestHelpers::Process::TEST_RUN_ROOT, "capybara")
    FileUtils.mkdir_p(root_dir)

    driver_options = ::Selenium::WebDriver::Chrome::Options.new
    driver_options.args << "--headless"

    # Allow connections to our self-signed SSL localhost test server.
    driver_options.args << "--allow-insecure-localhost"

    # Use /tmp instead of /dev/shm for Docker environments where /dev/shm is
    # too small:
    # https://github.com/GoogleChrome/puppeteer/blob/v1.10.0/docs/troubleshooting.md#tips
    driver_options.args << "--disable-dev-shm-usage"

    if options[:lang]
      driver_options.args << "--lang=#{options[:lang]}"
    end

    capabilities = ::Selenium::WebDriver::Remote::Capabilities.chrome({
      :loggingPrefs => {
        :browser => "ALL",
      },
    })

    driver = ::Capybara::Selenium::Driver.new(app, {
      :browser => :chrome,
      :options => driver_options,
      :desired_capabilities => capabilities,
      :driver_opts => {
        :log_path => File.join(root_dir, "#{driver_name}.log"),
        :verbose => true,
      },
    })
    driver.resize_window_to(driver.current_window_handle, 1200, 1200)

    driver
  end

  Capybara::Screenshot.register_driver(driver_name) do |driver, path|
    driver.browser.save_screenshot(path)
  end
end

capybara_register_driver(:selenium_chrome_headless)
Capybara.default_driver = :selenium_chrome_headless
Capybara.default_max_wait_time = 5
Capybara.run_server = false
Capybara.app_host = "https://127.0.0.1:9081"
Capybara.save_path = File.join(API_UMBRELLA_SRC_ROOT, "test/tmp/capybara")

Capybara::Chromedriver::Logger.raise_js_errors = true
Capybara::Chromedriver::Logger.filters = [
  # Ignore warnings about the self-signed localhost cert.
  /127.0.0.1.*This site does not have a valid SSL certificate/,
]

module Minitest
  module Capybara
    class Test < Minitest::Test
      include ::Capybara::DSL
      include ::Capybara::Minitest::Assertions

      attr_accessor :raise_js_errors

      def teardown
        super

        # Clear the session and logout after each test.
        ::Capybara.reset_sessions!

        # Ensure the default driver is used again for future tests (for any
        # tests that may have changed the driver).
        ::Capybara.use_default_driver

        # Inspect console logs/errors after each test and raise errors if
        # JavaScript errors were encountered.
        unless @skip_raise_js_errors
          ::Capybara::Chromedriver::Logger::TestHooks.after_example!
        end
      end
    end
  end
end
