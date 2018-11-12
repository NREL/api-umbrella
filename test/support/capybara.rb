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
    driver.resize_window_to(driver.current_window_handle, 1200, 4000)

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

# Since we're using custom styled checkboxes and radios, the actual inputs
# aren't visible. So enable this option so that Capybara will fallback to
# searching and clicking on the label for the associated checkbox when calling
# "check" and "uncheck".
Capybara.automatic_label_click = true

Capybara::Screenshot.prune_strategy = :keep_last_run

Capybara::Chromedriver::Logger.raise_js_errors = true
Capybara::Chromedriver::Logger.filters = [
  # Ignore warnings about the self-signed localhost cert.
  /127.0.0.1.*This site does not have a valid SSL certificate/,

  # Ignore expected ajax request failures.
  /127.0.0.1.*the server responded with a status of 403/,
  /127.0.0.1.*the server responded with a status of 422/,
]

module Minitest
  module Capybara
    class Test < Minitest::Test
      include ::Capybara::DSL
      include ::Capybara::Minitest::Assertions

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

      # For our custom radio/checkboxes, we need to click on the label, rather
      # than the input (since the input is technically hidden and only
      # virtually shown). The "automatic_label_click" option makes this work in
      # most cases, so we can use the default "check" and "uncheck" helpers",
      # however for our "User agrees to the terms and conditions" checkbox,
      # this doesn't work, since that label also has a link tag embedded
      # inside, so clicking on the center of the label ends up triggering the
      # popup, rather than the checkbox checking/unchecking.
      #
      # So these batch of label helpers are for cases where we know we need to
      # click directly on the label, and they also accept ":click" options that
      # are passed along to the label click for controlling it's position.
      #
      # Should be identical to the existing implementation, except that it
      # accepts the click options, and we don't bother trying to click on the
      # checkbox/radio first:
      # https://github.com/teamcapybara/capybara/blob/3.10.1/lib/capybara/node/actions.rb#L323
      def label_choose(locator = nil, **options)
        _custom_check_with_label(:radio_button, true, locator, options)
      end

      def label_check(locator = nil, **options)
        _custom_check_with_label(:checkbox, true, locator, options)
      end

      def label_uncheck(locator = nil, **options)
        _custom_check_with_label(:checkbox, false, locator, options)
      end

      def _custom_check_with_label(selector, checked, locator, **options)
        options[:allow_self] = true if locator.nil?
        click_options = options.delete(:click) || {}

        el = find(selector, locator, options.merge(:visible => :all))
        el.session.find(:label, :for => el, :visible => true).click(click_options) unless el.checked? == checked
      end

      def custom_input_trigger_click(input)
        # Ensure there's a label for the custom checkbox or radio styling.
        label = find(:label, :for => input, :visible => true)
        assert(label.text)

        id = input[:id]
        assert(id)
        page.execute_script("document.getElementById('#{id}').click()")
      end

      def fill_in_codemirror(locator, options = {})
        input = find_field(locator, :visible => :all)

        # Click on the label to force the codemirror input to focus. Otherwise,
        # the input field is invisible and text can't be entered until this
        # focus happens.
        label = find(:label, :for => input)
        label.click

        fill_in(locator, options.merge(:visible => :all))
      end

      def assert_codemirror_field(locator, options = {})
        input = find_field(locator, :visible => :all)

        # Verify that the displayed text by code mirror contains the expected
        # value, along with the expected line numbers.
        expected_value = options.fetch(:with)
        expected_text = expected_value.split("\n").map.with_index(1) do |line_value, line_num|
          "#{line_num}\n#{line_value}"
        end.join("\n")
        assert_selector("#" + input["data-codemirror-wrapper-element-id"], :text => expected_text)

        # Verify that the hidden original textarea contains the expected value.
        assert_equal(expected_value, find_by_id(input["data-codemirror-original-textarea-id"], :visible => :all).value)
      end
    end
  end
end
