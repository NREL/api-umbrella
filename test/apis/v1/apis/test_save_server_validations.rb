require_relative "../../../test_helper"

class Test::Apis::V1::Apis::TestSaveServerValidations < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::ApiSaveValidations
  include ApiUmbrellaTestHelpers::Setup

  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_accepts_valid_server
    assert_valid({
      :servers => [
        FactoryBot.attributes_for(:api_backend_server),
      ],
    })
  end

  def test_rejects_null_host
    assert_invalid({
      :servers => [
        FactoryBot.attributes_for(:api_backend_server, :host => nil),
      ],
    }, ["servers[0].host"])
  end

  def test_rejects_blank_host
    assert_invalid({
      :servers => [
        FactoryBot.attributes_for(:api_backend_server, :host => ""),
      ],
    }, ["servers[0].host"])
  end

  def test_rejects_invalid_host
    assert_invalid({
      :servers => [
        FactoryBot.attributes_for(:api_backend_server, :host => " z "),
      ],
    }, ["servers[0].host"])
  end

  def test_rejects_null_port
    assert_invalid({
      :servers => [
        FactoryBot.attributes_for(:api_backend_server, :port => nil),
      ],
    }, ["servers[0].port"])
  end

  def test_rejects_blank_port
    assert_invalid({
      :servers => [
        FactoryBot.attributes_for(:api_backend_server, :port => ""),
      ],
    }, ["servers[0].port"])
  end

  def test_rejects_invalid_port
    assert_invalid({
      :servers => [
        FactoryBot.attributes_for(:api_backend_server, :port => "zzz"),
      ],
    }, ["servers[0].port"])
  end

  def test_rejects_duplicate_hosts
    assert_invalid({
      :servers => [
        FactoryBot.attributes_for(:api_backend_server, :host => "example.com", :port => 80),
        FactoryBot.attributes_for(:api_backend_server, :host => "example.com", :port => 80),
      ],
    }, ["servers[1].host"])
  end

  def test_accepts_duplicate_hosts_with_differing_port
    assert_valid({
      :servers => [
        FactoryBot.attributes_for(:api_backend_server, :host => "example.com", :port => 80),
        FactoryBot.attributes_for(:api_backend_server, :host => "example.com", :port => 81),
      ],
    })
  end

  def test_accepts_duplicate_hosts_on_different_apis
    assert_valid({
      :servers => [
        FactoryBot.attributes_for(:api_backend_server, :host => "example.com", :port => 80),
      ],
    })
    assert_valid({
      :servers => [
        FactoryBot.attributes_for(:api_backend_server, :host => "example.com", :port => 80),
      ],
    })
  end
end
