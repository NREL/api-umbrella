module ApiUmbrellaTestHelpers
  module Selenium
    private

    def selenium_add_cookie(name, value)
      selenium_ensure_cookies
      browser = Capybara.current_session.driver.browser
      browser.manage.add_cookie(:name => name, :value => value)
    end

    def selenium_delete_cookie(name)
      selenium_ensure_cookies
      browser = Capybara.current_session.driver.browser
      browser.manage.delete_cookie(name)
    end

    def selenium_all_cookies
      selenium_ensure_cookies
      browser = Capybara.current_session.driver.browser
      browser.manage.all_cookies
    end

    def selenium_cookie_named(name)
      selenium_ensure_cookies
      browser = Capybara.current_session.driver.browser
      browser.manage.cookie_named(name)
    end

    def selenium_ensure_cookies
      # In order to set cookies, at least some page has to have been visited
      # first. So if no page is currently loaded, load the simple API endpoint
      # (since it should be quick and reliable).
      if current_host.nil?
        visit "/api-umbrella/v1/state"
      end
    end

    def selenium_use_language_driver(language)
      driver_name = :"selenium_chromium_headless_language_#{language}"
      unless Capybara.drivers[driver_name]
        capybara_register_driver(driver_name, {
          :lang => language,
        })
      end

      Capybara.current_driver = driver_name
    end
  end
end
