require_relative "../../../test_helper"

class Test::Apis::V1::Apis::TestSaveHostValidations < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup
  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_accepts_external_hostname
    assert_hostname_valid("example.com")
  end

  def test_accepts_internal_hostname
    assert_hostname_valid("localhost")
  end

  def test_accepts_ipv4_address
    assert_hostname_valid("127.0.0.1")
  end

  def test_accepts_compacted_ipv6_address
    assert_hostname_valid("::1")
  end

  def test_accepts_full_ipv6_address
    assert_hostname_valid("2001:db8:85a3::8a2e:370:7334")
  end

  def test_rejects_hostname_with_protocol_prefix
    assert_hostname_invalid("http://example.com")
  end

  def test_rejects_hostname_with_trailing_slash
    assert_hostname_invalid("example.com/")
  end

  def test_rejects_hostname_with_path_suffix
    assert_hostname_invalid("example.com/test")
  end

  def test_accepts_wildcard_for_frontend_backend_rejects_for_server
    assert_hostnames_invalid({
      :frontend_host => "*",
      :backend_host => "*",
      :servers => [
        FactoryBot.attributes_for(:api_backend_server, :host => "*"),
      ],
    }, [:servers])
  end

  def test_accepts_empty_backend_when_frontend_wildcard
    assert_hostnames_valid({
      :frontend_host => "*",
      :backend_host => "",
      :servers => [
        FactoryBot.attributes_for(:api_backend_server, :host => "127.0.0.1"),
      ],
    })
  end

  def test_accepts_null_backend_when_frontend_wildcard
    assert_hostnames_valid({
      :frontend_host => "*",
      :backend_host => nil,
      :servers => [
        FactoryBot.attributes_for(:api_backend_server, :host => "127.0.0.1"),
      ],
    })
  end

  def test_accepts_null_backend_when_frontend_wildcard_with_dot
    assert_hostnames_valid({
      :frontend_host => "*.example.com",
      :backend_host => nil,
      :servers => [
        FactoryBot.attributes_for(:api_backend_server, :host => "127.0.0.1"),
      ],
    })
  end

  def test_rejects_null_backend_when_frontend_not_wildcard
    assert_hostnames_invalid({
      :frontend_host => "example.com",
      :backend_host => nil,
      :servers => [
        FactoryBot.attributes_for(:api_backend_server, :host => "127.0.0.1"),
      ],
    }, [:backend_host])
  end

  def test_rejects_null_backend_when_frontend_wildcard_in_middle
    assert_hostnames_invalid({
      :frontend_host => "exam*ple.com",
      :backend_host => nil,
      :servers => [
        FactoryBot.attributes_for(:api_backend_server, :host => "127.0.0.1"),
      ],
    }, [:frontend_host, :backend_host])
  end

  def test_rejects_frontend_backend_wildcard_without_dot
    assert_hostnames_invalid({
      :frontend_host => "*example.com",
      :backend_host => "*example.com",
      :servers => [
        FactoryBot.attributes_for(:api_backend_server, :host => "127.0.0.1"),
      ],
    }, [:frontend_host, :backend_host])
  end

  def test_accepts_frontend_backend_wildcard_with_dot
    assert_hostnames_valid({
      :frontend_host => "*.example.com",
      :backend_host => "*.example.com",
      :servers => [
        FactoryBot.attributes_for(:api_backend_server, :host => "127.0.0.1"),
      ],
    })
  end

  def test_accepts_frontend_backend_dot_wildcard
    assert_hostnames_valid({
      :frontend_host => ".example.com",
      :backend_host => ".example.com",
      :servers => [
        FactoryBot.attributes_for(:api_backend_server, :host => "127.0.0.1"),
      ],
    })
  end

  def test_rejects_frontend_dot
    assert_hostnames_invalid({
      :frontend_host => ".",
      :backend_host => "example.com",
      :servers => [
        FactoryBot.attributes_for(:api_backend_server, :host => "127.0.0.1"),
      ],
    }, [:frontend_host])
  end

  def test_rejects_frontend_star_dot
    assert_hostnames_invalid({
      :frontend_host => "*.",
      :backend_host => "example.com",
      :servers => [
        FactoryBot.attributes_for(:api_backend_server, :host => "127.0.0.1"),
      ],
    }, [:frontend_host])
  end

  private

  def assert_hostname_valid(value)
    overrides = {
      :frontend_host => value,
      :backend_host => value,
      :servers => [
        FactoryBot.attributes_for(:api_backend_server, :host => value),
      ],
    }

    assert_hostnames_valid(overrides)
  end

  def assert_hostnames_valid(overrides)
    assert_hostnames_valid_create(overrides)
    assert_hostnames_valid_update(overrides)
  end

  def assert_hostnames_valid_create(overrides)
    assert_hostnames_valid_action(:create, overrides)
  end

  def assert_hostnames_valid_update(overrides)
    assert_hostnames_valid_action(:update, overrides)
  end

  def assert_hostnames_valid_action(action, overrides)
    attributes = attributes_for(action).deep_merge(overrides.deep_stringify_keys)

    response = create_or_update(action, attributes)
    case action
    when :create
      assert_response_code(201, response)
      data = MultiJson.load(response.body)
      api = ApiBackend.find(data["api"]["id"])
    when :update
      assert_response_code(204, response)
      api = ApiBackend.find(attributes["id"])
    end
    assert_equal(attributes.fetch("frontend_host"), api.frontend_host)
    if(attributes.fetch("backend_host").nil?)
      assert_nil(api.backend_host)
    else
      assert_equal(attributes.fetch("backend_host"), api.backend_host)
    end
    assert_equal(1, api.servers.length)
    assert_equal(attributes.fetch("servers")[0].fetch("host"), api.servers[0].host)
  end

  def assert_hostname_invalid(value)
    overrides = {
      :frontend_host => value,
      :backend_host => value,
    }
    assert_hostnames_invalid(overrides, [
      :frontend_host,
      :backend_host,
    ])

    overrides = {
      :servers => [
        FactoryBot.attributes_for(:api_backend_server, :host => value),
      ],
    }
    assert_hostnames_invalid(overrides, [
      :servers,
    ])
  end

  def assert_hostnames_invalid(overrides, expected_error_fields)
    assert_hostnames_invalid_create(overrides, expected_error_fields)
    assert_hostnames_invalid_update(overrides, expected_error_fields)
  end

  def assert_hostnames_invalid_create(overrides, expected_error_fields)
    assert_hostnames_invalid_action(:create, overrides, expected_error_fields)
  end

  def assert_hostnames_invalid_update(overrides, expected_error_fields)
    assert_hostnames_invalid_action(:update, overrides, expected_error_fields)
  end

  def assert_hostnames_invalid_action(action, overrides, expected_error_fields)
    attributes = attributes_for(action).deep_merge(overrides.deep_stringify_keys)

    response = create_or_update(action, attributes)
    assert_response_code(422, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)

    expected_error_fields = expected_error_fields.map do |field|
      if(field == :servers)
        field = "servers[0].host"
      end

      field.to_s
    end

    assert_equal(expected_error_fields.sort, data["errors"].keys.sort)
    expected_error_fields.each do |field|
      if(attributes.key?(field) && attributes[field].blank?)
        assert_includes(data["errors"][field], "can't be blank")
      else
        assert_includes(data["errors"][field], 'must be in the format of "example.com"')
      end
    end
  end

  def attributes_for(action)
    case action
    when :create
      FactoryBot.attributes_for(:api_backend).deep_stringify_keys
    when :update
      FactoryBot.create(:api_backend).serializable_hash
    else
      flunk("Unknown action: #{action.inspect}")
    end
  end

  def create_or_update(action, attributes)
    case action
    when :create
      Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/apis.json", http_options.deep_merge(admin_token).deep_merge({
        :headers => { "Content-Type" => "application/json" },
        :body => MultiJson.dump(:api => attributes),
      }))
    when :update
      Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{attributes["id"]}.json", http_options.deep_merge(admin_token).deep_merge({
        :headers => { "Content-Type" => "application/json" },
        :body => MultiJson.dump(:api => attributes),
      }))
    else
      flunk("Unknown action: #{action.inspect}")
    end
  end
end
