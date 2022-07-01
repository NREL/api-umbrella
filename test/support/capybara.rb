require "capybara/minitest"
require "capybara-screenshot/minitest"
require "open3"
require "support/api_umbrella_test_helpers/admin_auth"
require "support/api_umbrella_test_helpers/capybara_codemirror"
require "support/api_umbrella_test_helpers/capybara_custom_bootstrap_inputs"
require "support/api_umbrella_test_helpers/capybara_selectize"
require "support/api_umbrella_test_helpers/downloads"
require "support/api_umbrella_test_helpers/process"

def capybara_register_driver(driver_name, options = {})
  ::Capybara.register_driver(driver_name) do |app|
    root_dir = File.join(ApiUmbrellaTestHelpers::Process::TEST_RUN_ROOT, "capybara")
    FileUtils.mkdir_p(root_dir)

    service_options = {}
    service_args = [
      "--log_path=#{File.join(root_dir, "#{driver_name}.log")}",
      "--verbose",
    ]

    output, status = Open3.capture2e("which", "chromedriver")
    if status.success?
      service_options[:path] = output.strip
    else
      raise "chromedriver not found: #{output}"
    end

    # If passing in a custom language, use a wrapper script to parse the
    # "--lang" argument into the LANG environment variable. We can't pass
    # environment variables directly into chromdriver, so that's why we need
    # the wrapper script. Chrome 80+ changes require this LANG environment
    # variable instead of realying on the "--lang" argument itself.
    #
    # https://github.com/SeleniumHQ/selenium/issues/5412
    # https://chromium.googlesource.com/chromium/src.git/+/b6a68c85183f42927186514212a8a9fd932a2413
    if options[:lang]
      service_options[:path] = File.expand_path("chromedriver_lang_wrapper", __dir__)
      service_args << "--lang=#{options[:lang]}"
    end

    service = ::Selenium::WebDriver::Service.chrome(**service_options.merge({
      :args => service_args,
    }))

    driver_options = ::Selenium::WebDriver::Chrome::Options.new
    driver_options.args << "--headless"

    # Allow connections to our self-signed SSL localhost test server.
    driver_options.args << "--allow-insecure-localhost"

    # Use /tmp instead of /dev/shm for Docker environments where /dev/shm is
    # too small:
    # https://github.com/GoogleChrome/puppeteer/blob/v1.10.0/docs/troubleshooting.md#tips
    driver_options.args << "--disable-dev-shm-usage"

    # Use a static user agent for some session tests.
    driver_options.args << "--user-agent=#{ApiUmbrellaTestHelpers::AdminAuth::STATIC_USER_AGENT}"

    # Allow for usage in Docker.
    driver_options.args << "--disable-setuid-sandbox"
    driver_options.args << "--no-sandbox"

    # Set download path for Chrome >= 77
    driver_options.add_preference(:download, :default_directory => ApiUmbrellaTestHelpers::Downloads::DOWNLOADS_ROOT)

    capabilities = ::Capybara::Chromedriver::Logger.build_capabilities(
      :chromeOptions => {
        :args => ["headless"],
      },
    )

    driver = ::Capybara::Selenium::Driver.new(app,
      :browser => :chrome,
      :service => service,
      :options => driver_options,
      :desired_capabilities => capabilities)
    driver.resize_window_to(driver.current_window_handle, 1200, 4000)

    # Set download path for Chrome < 77
    driver.browser.download_path = ApiUmbrellaTestHelpers::Downloads::DOWNLOADS_ROOT

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
Capybara.save_path = File.join(API_UMBRELLA_SRC_ROOT, "test/tmp/artifacts/capybara")

# Since we're using custom styled checkboxes and radios, the actual inputs
# aren't visible. So enable this option so that Capybara will fallback to
# searching and clicking on the label for the associated checkbox when calling
# "check" and "uncheck".
Capybara.automatic_label_click = true

# Attempted workaround for "fill_in" sometimes not clearing existing input:
# https://github.com/teamcapybara/capybara/issues/2419#issuecomment-738798878
#
# This seems to crop up most frequently with the
# Test::AdminUi::TestApis#test_form test not properly clearing the "Frontend
# Host" field, so we end up with both the default value 127.0.0.1 plus the new
# value, of api.foo.com all in one string ("127.0.0.1api.foo.com").
Capybara.default_set_options = { :clear => :backspace }

Capybara::Screenshot.prune_strategy = :keep_last_run

Capybara::Chromedriver::Logger.raise_js_errors = true
Capybara::Chromedriver::Logger.filters = [
  # Ignore warnings about the self-signed localhost cert.
  /127.0.0.1.*This site does not have a valid SSL certificate/,

  # Ignore expected ajax request failures.
  /127.0.0.1.*the server responded with a status of 401/,
  /127.0.0.1.*the server responded with a status of 403/,
  /127.0.0.1.*the server responded with a status of 422/,
]

module Minitest
  module Capybara
    class Test < Minitest::Test
      include ::Capybara::DSL
      include ::Capybara::Minitest::Assertions
      include ApiUmbrellaTestHelpers::CapybaraCodemirror
      include ApiUmbrellaTestHelpers::CapybaraCustomBootstrapInputs
      include ApiUmbrellaTestHelpers::CapybaraSelectize

      def teardown
        super

        # Clear the session and logout after each test.
        ::Capybara.reset_sessions!

        # Ensure the default driver is used again for future tests (for any
        # tests that may have changed the driver).
        ::Capybara.use_default_driver

        # Inspect console logs/errors after each test and raise errors if
        # JavaScript errors were encountered.
        ::Capybara::Chromedriver::Logger::TestHooks.after_example!
      end
    end
  end
end
