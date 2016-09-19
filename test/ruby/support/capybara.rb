require "capybara/poltergeist"
require "capybara-screenshot/minitest"

class PoltergeistLogger
  attr_reader :logger

  def initialize(path)
    @logger = Logger.new(path)# ::Logger::Formatter.new
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

Capybara.default_max_wait_time = 5
Capybara.register_driver :poltergeist do |app|
  Capybara::Poltergeist::Driver.new(app, {
    :logger => PoltergeistLogger.new("/tmp/test_poltergeist.log"),
    :phantomjs_logger => PoltergeistLogger.new("/tmp/test_phantomjs.log"),
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
