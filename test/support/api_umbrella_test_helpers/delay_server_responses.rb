require "support/api_umbrella_test_helpers/selenium"

module ApiUmbrellaTestHelpers
  module DelayServerResponses
    include ApiUmbrellaTestHelpers::Selenium

    # Set a cookie to slow down server side responses. This relies on the
    # TestDelayServerResponses middleware we install into the Rails app in the
    # test environment.
    #
    # This gives a way to test certain things on the page that might go away
    # too quickly if the server responds too quickly (for example, testing
    # loading spinners showing up during an ajax call).
    def delay_server_responses(delay)
      Capybara.reset_session!
      selenium_add_cookie("test_delay_server_responses", delay.to_s)
      yield
    ensure
      selenium_delete_cookie("test_delay_server_responses")
    end
  end
end
