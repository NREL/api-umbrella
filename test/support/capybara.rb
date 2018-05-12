require "capybara/minitest"
require "capybara/poltergeist"
require "capybara-screenshot/minitest"
require "support/api_umbrella_test_helpers/process"

class PoltergeistLogger
  attr_reader :logger

  def initialize(path)
    @logger = Logger.new(path)
  end

  def puts(line)
    @logger.info(line)
  end

  def write(msg)
    if(msg)
      @line ||= ""
      @line << msg.chomp

      if(msg.include?("\n"))
        @logger.info(@line)
        @line = ""
      end
    end
  end
end

root_dir = File.join(ApiUmbrellaTestHelpers::Process::TEST_RUN_ROOT, "capybara")

Capybara.default_max_wait_time = 5
Capybara.register_driver :poltergeist do |app|
  FileUtils.mkdir_p(root_dir)
  Capybara::Poltergeist::Driver.new(app, {
    :logger => PoltergeistLogger.new(File.join(root_dir, "poltergeist.log")),
    :phantomjs_logger => PoltergeistLogger.new(File.join(root_dir, "phantomjs.log")),
    :phantomjs_options => [
      "--ignore-ssl-errors=true",
      # Use disk-based cache for more accurate browser caching behavior:
      # https://github.com/teampoltergeist/poltergeist/issues/754#issuecomment-228433228
      "--disk-cache=true",
      "--disk-cache-path=#{File.join(root_dir, "disk-cache")}",
      "--offline-storage-path=#{File.join(root_dir, "offline-storage")}",
      "--local-storage-path=#{File.join(root_dir, "local-storage")}",
    ],
    :extensions => [
      File.join(API_UMBRELLA_SRC_ROOT, "test/support/capybara/disable_animations.js"),
      File.join(API_UMBRELLA_SRC_ROOT, "test/support/capybara/disable_fixed_header.js"),
      File.join(API_UMBRELLA_SRC_ROOT, "test/support/capybara/timekeeper.js"),
    ],
  })
end
Capybara.default_driver = :poltergeist
Capybara.run_server = false
Capybara.app_host = "https://127.0.0.1:9081"
Capybara.save_path = File.join(API_UMBRELLA_SRC_ROOT, "test/tmp/capybara")

module Minitest
  module Capybara
    class Test < Minitest::Test
      include ::Capybara::DSL
      include ::Capybara::Minitest::Assertions

      # After each capybara test, also clear the memory cache in Poltergeist. This
      # seems to be necessary to prevent Poltergeist from incorrectly caching
      # redirect results across different tests, and other oddities:
      # https://github.com/teampoltergeist/poltergeist/issues/754
      def teardown
        super
        ::Capybara.reset_session!
        page.driver.clear_memory_cache
        ::Capybara.use_default_driver
      end
    end
  end
end
