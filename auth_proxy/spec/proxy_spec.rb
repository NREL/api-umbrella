require "spec_helper"
require "auth_proxy/proxy"

describe AuthProxy::Proxy do
  describe "proxymachine_router" do
    it "should be a Proc for passing into ProxyMachine's `proxy`" do
      AuthProxy::Proxy.proxymachine_router.class.should == Proc
    end
  end
end
