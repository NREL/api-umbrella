require "spec_helper"
require "api-umbrella-gatekeeper"

describe ApiUmbrella::Gatekeeper do
  describe "redis" do
    it "is a Redis instance" do
      ApiUmbrella::Gatekeeper.redis.should be_instance_of(Redis)
    end

    it "is able to connect to the Redis server" do
      expect { ApiUmbrella::Gatekeeper.redis.client.connect }.to_not raise_error
    end
  end

  describe "logger" do
    it "is a Logger instance" do
      ApiUmbrella::Gatekeeper.logger.should be_instance_of(Logger)
    end
  end
end
