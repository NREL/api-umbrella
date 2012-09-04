ENV["RACK_ENV"] = "test"

ENV["MONGO_SPEC_HOST"] ||= "localhost"
ENV["MONGO_SPEC_PORT"] ||= "27017"

$LOAD_PATH.unshift(File.expand_path("../../app/models", __FILE__))

require "api-umbrella-gatekeeper"
require "database_cleaner"
require "factory_girl"
require "fileutils"
require "mongoid"
require "nokogiri"
require "rack/test"
require "redis"
require "timecop"
require "yajl"

# When testing locally we use the database named mongoid_test. However when
# tests are running in parallel on Travis we need to use different database
# names for each process running since we do not have transactions and want a
# clean slate before each spec run.
def database_id
  ENV["CI"] ? "mongoid_#{Process.pid}" : "mongoid_test"
end

# Set the database that the spec suite connects to.
Mongoid.configure do |config|
  database = Mongo::Connection.new(ENV["MONGO_SPEC_HOST"], ENV["MONGO_SPEC_PORT"]).db(database_id)
  database.add_user("mongoid", "test")
  config.master = database
  config.logger = nil
end

FactoryGirl.find_definitions

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
    }.map { |k, v| "#{k} #{v}" }.join('\n')
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
