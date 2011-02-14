require "spec_helper"
require "auth_proxy/rack_app"

describe AuthProxy::RackApp do
  describe "redis_cache" do
    it "should be a Redis instance" do
      AuthProxy::RackApp.redis_cache.should be_instance_of(Redis)
    end

    it "should be a singleton" do
      AuthProxy::RackApp.redis_cache.should equal(AuthProxy::RackApp.redis_cache)
    end
  end

  describe "instance" do
    it "should be a Rack application" do
      puts AuthProxy::RackApp.instance.inspect
      #AuthProxy::RackApp.instance.must_be_instance_of(Rack::Builder)
    end

    it "should be a singleton" do
      AuthProxy::RackApp.instance.should equal(AuthProxy::RackApp.instance)
    end
  end
end
