require "spec_helper"

describe ApiUmbrella::Gatekeeper::Server do
  describe "rack conformance" do
    it "passes the rack lint tests" do
      ApiUmbrella::Gatekeeper::ConnectionHandler.any_instance.stub(:gatekeeper_instruction) do |rack_env|
        expect {
          app = lambda { |env| [200, {}, ["OK"]] }
          app = ::Rack::Lint.new(app)
          app.call(rack_env)
        }.to_not raise_error

        {
          :status => 200,
          :headers => {},
          :response => "",
        }
      end

      make_request(:get, "/hello")
    end
  end
end
