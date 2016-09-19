require "capybara/poltergeist"
require "capybara-screenshot/minitest"

Capybara.default_max_wait_time = 5
Capybara.register_driver :poltergeist do |app|
  Capybara::Poltergeist::Driver.new(app, {
    :phantomjs_logger => File.open("/tmp/test_phantomjs.log", "a"),
    :phantomjs_options => [
      "--ignore-ssl-errors=true",
      "--disk-cache-path=/tmp/capybara-disk-cache",
      "--offline-storage-path=/tmp/capybara-offline-storage",
      "--local-storage-path=/tmp/capybara-local-storage",
    ],
    :extensions => [
      File.expand_path("../capybara/disable_animations.js", __FILE__),
    ],
  })
end
Capybara.default_driver = :poltergeist
Capybara.run_server = false
Capybara.app_host = "https://127.0.0.1:9081"

FileUtils.rm_rf("/tmp/capybara-disk-cache")
FileUtils.rm_rf("/tmp/capybara-offline-storage")
FileUtils.rm_rf("/tmp/capybara-local-storage")
