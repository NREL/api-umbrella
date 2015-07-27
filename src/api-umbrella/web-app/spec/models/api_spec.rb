require 'spec_helper'

describe Api do
  context "host validations" do
    shared_examples "valid host" do
      it "passes validations" do
        api.valid?.should eql(true)
      end
    end

    shared_examples "invalid host" do
      it "fails validations" do
        api.valid?.should eql(false)
        api.errors.messages.keys.sort.should eql([
          :backend_host,
          :frontend_host,
          :"servers[0].host"
        ])

        api.errors_on(:backend_host).should include('must be in the format of "example.com"')
        api.errors_on(:frontend_host).should include('must be in the format of "example.com"')
        api.errors_on(:"servers[0].host").should include('must be in the format of "example.com"')
      end
    end

    describe "accepts a external hostname" do
      let(:api) do
        FactoryGirl.build(:api, {
          :frontend_host => "example.com",
          :backend_host => "example.com",
          :servers => [
            FactoryGirl.attributes_for(:api_server, :host => "example.com"),
          ]
        })
      end

      it_behaves_like "valid host"
    end

    describe "accepts a internal hostname" do
      let(:api) do
        FactoryGirl.build(:api, {
          :frontend_host => "localhost",
          :backend_host => "localhost",
          :servers => [
            FactoryGirl.attributes_for(:api_server, :host => "localhost"),
          ]
        })
      end

      it_behaves_like "valid host"
    end

    describe "accepts an IPv4 address" do
      let(:api) do
        FactoryGirl.build(:api, {
          :frontend_host => "127.0.0.1",
          :backend_host => "127.0.0.1",
          :servers => [
            FactoryGirl.attributes_for(:api_server, :host => "127.0.0.1"),
          ]
        })
      end

      it_behaves_like "valid host"
    end

    describe "accepts a compacted IPv6 address" do
      let(:api) do
        FactoryGirl.build(:api, {
          :frontend_host => "::1",
          :backend_host => "::1",
          :servers => [
            FactoryGirl.attributes_for(:api_server, :host => "::1"),
          ]
        })
      end

      it_behaves_like "valid host"
    end

    describe "accepts a full IPv6 address" do
      let(:api) do
        FactoryGirl.build(:api, {
          :frontend_host => "2001:db8:85a3::8a2e:370:7334",
          :backend_host => "2001:db8:85a3::8a2e:370:7334",
          :servers => [
            FactoryGirl.attributes_for(:api_server, :host => "2001:db8:85a3::8a2e:370:7334"),
          ]
        })
      end

      it_behaves_like "valid host"
    end

    describe "rejects a hostname with a protocol prefix" do
      let(:api) do
        FactoryGirl.build(:api, {
          :frontend_host => "http://example.com",
          :backend_host => "http://example.com",
          :servers => [
            FactoryGirl.attributes_for(:api_server, :host => "http://example.com"),
          ]
        })
      end

      it_behaves_like "invalid host"
    end

    describe "rejects a hostname with a trailing slash" do
      let(:api) do
        FactoryGirl.build(:api, {
          :frontend_host => "example.com/",
          :backend_host => "example.com/",
          :servers => [
            FactoryGirl.attributes_for(:api_server, :host => "example.com/"),
          ]
        })
      end

      it_behaves_like "invalid host"
    end

    describe "rejects a hostname with a path suffix" do
      let(:api) do
        FactoryGirl.build(:api, {
          :frontend_host => "example.com/test",
          :backend_host => "example.com/test",
          :servers => [
            FactoryGirl.attributes_for(:api_server, :host => "example.com/test"),
          ]
        })
      end

      it_behaves_like "invalid host"
    end

    it "allows a wildcard for the frontend host or backend host, but not for server host" do
      api = FactoryGirl.build(:api, {
        :frontend_host => "*",
        :backend_host => "*",
        :servers => [
          FactoryGirl.attributes_for(:api_server, :host => "*"),
        ]
      })

      api.valid?.should eql(false)
      api.errors.messages.keys.sort.should eql([
        :"servers[0].host"
      ])

      api.errors_on(:"servers[0].host").should include('must be in the format of "example.com"')
    end

    it "allows an empty string backend host when the frontend host is a wildcard" do
      api = FactoryGirl.build(:api, {
        :frontend_host => "*",
        :backend_host => "",
        :servers => [
          FactoryGirl.attributes_for(:api_server, :host => "127.0.0.1"),
        ]
      })

      api.valid?.should eql(true)
    end

    it "allows an null backend host when the frontend host is a wildcard" do
      api = FactoryGirl.build(:api, {
        :frontend_host => "*",
        :backend_host => nil,
        :servers => [
          FactoryGirl.attributes_for(:api_server, :host => "127.0.0.1"),
        ]
      })

      api.valid?.should eql(true)
    end

    it "allows an empty backend host when the frontend host contains a wildcard with dot" do
      api = FactoryGirl.build(:api, {
        :frontend_host => "*.example.com",
        :backend_host => nil,
        :servers => [
          FactoryGirl.attributes_for(:api_server, :host => "127.0.0.1"),
        ]
      })

      api.valid?.should eql(true)
    end

    it "does not allow a frontend or backend host starting with a wildcard when not bordered by a dot" do
      api = FactoryGirl.build(:api, {
        :frontend_host => "*example.com",
        :backend_host => "*example.com",
        :servers => [
          FactoryGirl.attributes_for(:api_server, :host => "127.0.0.1"),
        ]
      })

      api.valid?.should eql(false)
      api.errors.messages.keys.sort.should eql([
        :backend_host,
        :frontend_host,
      ])
    end

    it "allows a frontend or backend host starting with a star dot" do
      api = FactoryGirl.build(:api, {
        :frontend_host => "*.example.com",
        :backend_host => "*.example.com",
        :servers => [
          FactoryGirl.attributes_for(:api_server, :host => "127.0.0.1"),
        ]
      })

      api.valid?.should eql(true)
    end

    it "allows a frontend or backend host starting with a dot" do
      api = FactoryGirl.build(:api, {
        :frontend_host => ".example.com",
        :backend_host => ".example.com",
        :servers => [
          FactoryGirl.attributes_for(:api_server, :host => "127.0.0.1"),
        ]
      })

      api.valid?.should eql(true)
    end

    it "does not allow a frontend host equal to '.'" do
      api = FactoryGirl.build(:api, {
        :frontend_host => ".",
        :backend_host => "example.com",
        :servers => [
          FactoryGirl.attributes_for(:api_server, :host => "127.0.0.1"),
        ]
      })

      api.valid?.should eql(false)
      api.errors.messages.keys.sort.should eql([
        :frontend_host,
      ])
    end

    it "does not allow a frontend host equal to '*.'" do
      api = FactoryGirl.build(:api, {
        :frontend_host => "*.",
        :backend_host => "example.com",
        :servers => [
          FactoryGirl.attributes_for(:api_server, :host => "127.0.0.1"),
        ]
      })

      api.valid?.should eql(false)
      api.errors.messages.keys.sort.should eql([
        :frontend_host,
      ])
    end

    it "does not allow an empty backend host when the frontend host does not contain a wildcard" do
      api = FactoryGirl.build(:api, {
        :frontend_host => "example.com",
        :backend_host => nil,
        :servers => [
          FactoryGirl.attributes_for(:api_server, :host => "127.0.0.1"),
        ]
      })

      api.valid?.should eql(false)
      api.errors.messages.keys.sort.should eql([
        :backend_host,
      ])
    end

    it "does not allow an empty backend host when the frontend host contains a wildcard in the middle" do
      api = FactoryGirl.build(:api, {
        :frontend_host => "exam*ple.com",
        :backend_host => nil,
        :servers => [
          FactoryGirl.attributes_for(:api_server, :host => "127.0.0.1"),
        ]
      })

      api.valid?.should eql(false)
      api.errors.messages.keys.sort.should eql([
        :backend_host,
        :frontend_host,
      ])
    end
  end
end
