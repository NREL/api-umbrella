ENV["RACK_ENV"] = "test"

require "api-umbrella-gatekeeper"
require "database_cleaner"
require "em-http-request"
require "fileutils"
require "nokogiri"
require "rack/test"
require "timecop"
require "yajl"

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[File.expand_path("../support/**/*.rb", __FILE__)].each {|f| require f}

RSpec.configure do |config|
  REDIS_PID = File.expand_path("../tmp/pids/redis-test.pid", __FILE__)
  REDIS_CACHE_PATH = File.expand_path("../tmp/cache/", __FILE__)

  config.before(:suite) do
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.orm = "mongoid"
    DatabaseCleaner.clean

    FileUtils.mkdir_p(File.dirname(REDIS_PID))
    FileUtils.mkdir_p(REDIS_CACHE_PATH)

    redis_options = {
      "daemonize"     => 'yes',
      "pidfile"       => REDIS_PID,
      "port"          => 9736,
      "timeout"       => 300,
      "save 900"      => 1,
      "save 300"      => 1,
      "save 60"       => 10000,
      "dbfilename"    => "dump.rdb",
      "dir"           => REDIS_CACHE_PATH,
      "loglevel"      => "debug",
      "logfile"       => "stdout",
      "databases"     => 16
    }.map { |k, v| "#{k} #{v}" }.join("\n")
    `echo '#{redis_options}' | redis-server -`

    sleep 0.2

    ApiUmbrella::Gatekeeper.redis = Redis.new(:host => "localhost", :port => 9736)
    ApiUmbrella::Gatekeeper.redis.flushall
  end

  config.after(:suite) do
    %x{
      cat #{REDIS_PID} | xargs kill -QUIT
      rm -f #{REDIS_CACHE_PATH}dump.rdb
    }
  end
end
