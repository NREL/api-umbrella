require_relative "../test_helper"

class Test::Proxy::TestForwardedPortHeaders < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include Minitest::Hooks

  def setup
    super
    setup_server

    @default_config = {
      :web => {
        :admin => {
          :auth_strategies => {
            :enabled => ["google"],
          },
        },
      },
    }

    once_per_class_setup do
      Admin.delete_all
      FactoryGirl.create(:admin)
      override_config_set(@default_config, ["--router", "--web"])
    end
  end

  def after_all
    super
    override_config_reset(["--router", "--web"])
  end

  def test_default_headers
    headers = {}
    responses = make_requests(headers)
    responses.each do |type, response|
      case(type)
      when :admin_https
        assert_response_code(200, response)
      when :admin_http
        assert_response_code(301, response)
        assert_equal("https://127.0.0.1:9081/admin/login", response.headers["Location"])
      when :admin_oauth2_https
        assert_response_code(302, response)
        assert_oauth2_redirect_uri("https://127.0.0.1:9081/admins/auth/google_oauth2/callback", response)
      when :admin_oauth2_http
        assert_response_code(301, response)
        assert_equal("https://127.0.0.1:9081/admins/auth/google_oauth2", response.headers["Location"])
      when :website_https
        assert_response_code(200, response)
      when :website_http
        assert_response_code(301, response)
        assert_equal("https://127.0.0.1:9081/", response.headers["Location"])
      when :website_signup_https
        assert_response_code(200, response)
      when :website_signup_http
        assert_response_code(301, response)
        assert_equal("https://127.0.0.1:9081/signup/", response.headers["Location"])
      else
        raise "Unhandled type: #{type}"
      end
    end
  end

  def test_forwarded_port
    headers = { "X-Forwarded-Port" => "1111" }
    responses = make_requests(headers)
    responses.each do |type, response|
      case(type)
      when :admin_https
        assert_response_code(200, response)
      when :admin_http
        assert_response_code(301, response)
        assert_equal("https://127.0.0.1:9081/admin/login", response.headers["Location"])
      when :admin_oauth2_https
        assert_response_code(302, response)
        assert_oauth2_redirect_uri("https://127.0.0.1:1111/admins/auth/google_oauth2/callback", response)
      when :admin_oauth2_http
        assert_response_code(301, response)
        assert_equal("https://127.0.0.1:9081/admins/auth/google_oauth2", response.headers["Location"])
      when :website_https
        assert_response_code(200, response)
      when :website_http
        assert_response_code(301, response)
        assert_equal("https://127.0.0.1:9081/", response.headers["Location"])
      when :website_signup_https
        assert_response_code(200, response)
      when :website_signup_http
        assert_response_code(301, response)
        assert_equal("https://127.0.0.1:9081/signup/", response.headers["Location"])
      else
        raise "Unhandled type: #{type}"
      end
    end
  end

  def test_forwarded_proto_http
    headers = { "X-Forwarded-Proto" => "http" }
    responses = make_requests(headers)
    responses.each do |type, response|
      case(type)
      when :admin_https, :admin_http
        assert_response_code(301, response)
        assert_equal("https://127.0.0.1:9081/admin/login", response.headers["Location"])
      when :admin_oauth2_https, :admin_oauth2_http
        assert_response_code(301, response)
        assert_equal("https://127.0.0.1:9081/admins/auth/google_oauth2", response.headers["Location"])
      when :website_https, :website_http
        assert_response_code(301, response)
        assert_equal("https://127.0.0.1:9081/", response.headers["Location"])
      when :website_signup_https, :website_signup_http
        assert_response_code(301, response)
        assert_equal("https://127.0.0.1:9081/signup/", response.headers["Location"])
      else
        raise "Unhandled type: #{type}"
      end
    end
  end

  def test_forwarded_proto_https
    headers = { "X-Forwarded-Proto" => "https" }
    responses = make_requests(headers)
    responses.each do |type, response|
      case(type)
      when :admin_https, :admin_http
        assert_response_code(200, response)
      when :admin_oauth2_https
        assert_response_code(302, response)
        assert_oauth2_redirect_uri("https://127.0.0.1:9081/admins/auth/google_oauth2/callback", response)
      when :admin_oauth2_http
        assert_response_code(302, response)
        assert_oauth2_redirect_uri("https://127.0.0.1:9080/admins/auth/google_oauth2/callback", response)
      when :website_https, :website_http
        assert_response_code(200, response)
      when :website_signup_https, :website_signup_http
        assert_response_code(200, response)
      else
        raise "Unhandled type: #{type}"
      end
    end
  end

  def test_forwarded_proto_http_and_port
    headers = { "X-Forwarded-Proto" => "http", "X-Forwarded-Port" => "1111" }
    responses = make_requests(headers)
    responses.each do |type, response|
      case(type)
      when :admin_https, :admin_http
        assert_response_code(301, response)
        assert_equal("https://127.0.0.1:9081/admin/login", response.headers["Location"])
      when :admin_oauth2_https, :admin_oauth2_http
        assert_response_code(301, response)
        assert_equal("https://127.0.0.1:9081/admins/auth/google_oauth2", response.headers["Location"])
      when :website_https, :website_http
        assert_response_code(301, response)
        assert_equal("https://127.0.0.1:9081/", response.headers["Location"])
      when :website_signup_https, :website_signup_http
        assert_response_code(301, response)
        assert_equal("https://127.0.0.1:9081/signup/", response.headers["Location"])
      else
        raise "Unhandled type: #{type}"
      end
    end
  end

  def test_forwarded_proto_https_and_port
    headers = { "X-Forwarded-Proto" => "https", "X-Forwarded-Port" => "1111" }
    responses = make_requests(headers)
    responses.each do |type, response|
      case(type)
      when :admin_https, :admin_http
        assert_response_code(200, response)
      when :admin_oauth2_https, :admin_oauth2_http
        assert_response_code(302, response)
        assert_oauth2_redirect_uri("https://127.0.0.1:1111/admins/auth/google_oauth2/callback", response)
      when :website_https, :website_http
        assert_response_code(200, response)
      when :website_signup_https, :website_signup_http
        assert_response_code(200, response)
      else
        raise "Unhandled type: #{type}"
      end
    end
  end

  def test_override_public_http_port
    override_config(@default_config.deep_merge({
      :override_public_http_port => 2222,
    }), "--router") do
      headers = { "X-Forwarded-Port" => "1111" }
      responses = make_requests(headers)
      responses.each do |type, response|
        case(type)
        when :admin_https
          assert_response_code(200, response)
        when :admin_http
          assert_response_code(301, response)
          assert_equal("https://127.0.0.1:9081/admin/login", response.headers["Location"])
        when :admin_oauth2_https
          assert_response_code(302, response)
          assert_oauth2_redirect_uri("https://127.0.0.1:1111/admins/auth/google_oauth2/callback", response)
        when :admin_oauth2_http
          assert_response_code(301, response)
          assert_equal("https://127.0.0.1:9081/admins/auth/google_oauth2", response.headers["Location"])
        when :website_https
          assert_response_code(200, response)
        when :website_http
          assert_response_code(301, response)
          assert_equal("https://127.0.0.1:9081/", response.headers["Location"])
        when :website_signup_https
          assert_response_code(200, response)
        when :website_signup_http
          assert_response_code(301, response)
          assert_equal("https://127.0.0.1:9081/signup/", response.headers["Location"])
        else
          raise "Unhandled type: #{type}"
        end
      end
    end
  end

  def test_override_public_https_port
    override_config(@default_config.deep_merge({
      :override_public_https_port => 3333,
    }), "--router") do
      headers = { "X-Forwarded-Port" => "1111" }
      responses = make_requests(headers)
      responses.each do |type, response|
        case(type)
        when :admin_https
          assert_response_code(200, response)
        when :admin_http
          assert_response_code(301, response)
          assert_equal("https://127.0.0.1:3333/admin/login", response.headers["Location"])
        when :admin_oauth2_https
          assert_response_code(302, response)
          assert_oauth2_redirect_uri("https://127.0.0.1:3333/admins/auth/google_oauth2/callback", response)
        when :admin_oauth2_http
          assert_response_code(301, response)
          assert_equal("https://127.0.0.1:3333/admins/auth/google_oauth2", response.headers["Location"])
        when :website_https
          assert_response_code(200, response)
        when :website_http
          assert_response_code(301, response)
          assert_equal("https://127.0.0.1:3333/", response.headers["Location"])
        when :website_signup_https
          assert_response_code(200, response)
        when :website_signup_http
          assert_response_code(301, response)
          assert_equal("https://127.0.0.1:3333/signup/", response.headers["Location"])
        else
          raise "Unhandled type: #{type}"
        end
      end
    end
  end

  def test_override_public_http_proto
    override_config(@default_config.deep_merge({
      :override_public_http_proto => "https",
    }), "--router") do
      headers = { "X-Forwarded-Proto" => "http" }
      responses = make_requests(headers)
      responses.each do |type, response|
        case(type)
        when :admin_https
          assert_response_code(301, response)
          assert_equal("https://127.0.0.1:9081/admin/login", response.headers["Location"])
        when :admin_http
          assert_response_code(200, response)
        when :admin_oauth2_https
          assert_response_code(301, response)
          assert_equal("https://127.0.0.1:9081/admins/auth/google_oauth2", response.headers["Location"])
        when :admin_oauth2_http
          assert_response_code(302, response)
          assert_oauth2_redirect_uri("https://127.0.0.1:9080/admins/auth/google_oauth2/callback", response)
        when :website_https
          assert_response_code(301, response)
          assert_equal("https://127.0.0.1:9081/", response.headers["Location"])
        when :website_http
          assert_response_code(200, response)
        when :website_signup_https
          assert_response_code(301, response)
          assert_equal("https://127.0.0.1:9081/signup/", response.headers["Location"])
        when :website_signup_http
          assert_response_code(200, response)
        else
          raise "Unhandled type: #{type}"
        end
      end
    end
  end

  def test_override_public_https_proto
    override_config(@default_config.deep_merge({
      :override_public_https_proto => "http",
    }), "--router") do
      headers = { "X-Forwarded-Proto" => "https" }
      responses = make_requests(headers)
      responses.each do |type, response|
        case(type)
        when :admin_https
          assert_response_code(301, response)
          assert_equal("https://127.0.0.1:9081/admin/login", response.headers["Location"])
        when :admin_http
          assert_response_code(200, response)
        when :admin_oauth2_https
          assert_response_code(301, response)
          assert_equal("https://127.0.0.1:9081/admins/auth/google_oauth2", response.headers["Location"])
        when :admin_oauth2_http
          assert_response_code(302, response)
          assert_oauth2_redirect_uri("https://127.0.0.1:9080/admins/auth/google_oauth2/callback", response)
        when :website_https
          assert_response_code(301, response)
          assert_equal("https://127.0.0.1:9081/", response.headers["Location"])
        when :website_http
          assert_response_code(200, response)
        when :website_signup_https
          assert_response_code(301, response)
          assert_equal("https://127.0.0.1:9081/signup/", response.headers["Location"])
        when :website_signup_http
          assert_response_code(200, response)
        else
          raise "Unhandled type: #{type}"
        end
      end
    end
  end

  def test_override_public_ports_defaults
    override_config(@default_config.deep_merge({
      :override_public_http_port => 80,
      :override_public_https_port => 443,
    }), "--router") do
      headers = {}
      responses = make_requests(headers)
      responses.each do |type, response|
        case(type)
        when :admin_https
          assert_response_code(200, response)
        when :admin_http
          assert_response_code(301, response)
          assert_equal("https://127.0.0.1/admin/login", response.headers["Location"])
        when :admin_oauth2_https
          assert_response_code(302, response)
          assert_oauth2_redirect_uri("https://127.0.0.1/admins/auth/google_oauth2/callback", response)
        when :admin_oauth2_http
          assert_response_code(301, response)
          assert_equal("https://127.0.0.1/admins/auth/google_oauth2", response.headers["Location"])
        when :website_https
          assert_response_code(200, response)
        when :website_http
          assert_response_code(301, response)
          assert_equal("https://127.0.0.1/", response.headers["Location"])
        when :website_signup_https
          assert_response_code(200, response)
        when :website_signup_http
          assert_response_code(301, response)
          assert_equal("https://127.0.0.1/signup/", response.headers["Location"])
        else
          raise "Unhandled type: #{type}"
        end
      end
    end
  end

  def test_override_public_ports_and_proto_ssl_terminator
    override_config(@default_config.deep_merge({
      :override_public_http_port => 443,
      :override_public_http_proto => "https",
      :override_public_https_port => 443,
      :override_public_https_proto => "https",
    }), "--router") do
      headers = {}
      responses = make_requests(headers)
      responses.each do |type, response|
        case(type)
        when :admin_https, :admin_http
          assert_response_code(200, response)
        when :admin_oauth2_https, :admin_oauth2_http
          assert_response_code(302, response)
          assert_oauth2_redirect_uri("https://127.0.0.1/admins/auth/google_oauth2/callback", response)
        when :website_https, :website_http
          assert_response_code(200, response)
        when :website_signup_https, :website_signup_http
          assert_response_code(200, response)
        else
          raise "Unhandled type: #{type}"
        end
      end
    end
  end

  private

  def assert_oauth2_redirect_uri(expected_uri, response)
    assert(response.headers["Location"])
    uri = Addressable::URI.parse(response.headers["Location"])
    assert_equal(expected_uri, uri.query_values["redirect_uri"])
  end

  def make_requests(headers)
    {
      :admin_https => admin_https_request(headers),
      :admin_http => admin_http_request(headers),
      :admin_oauth2_https => admin_oauth2_https_request(headers),
      :admin_oauth2_http => admin_oauth2_http_request(headers),
      :website_https => website_https_request(headers),
      :website_http => website_http_request(headers),
      :website_signup_https => website_signup_https_request(headers),
      :website_signup_http => website_signup_http_request(headers),
    }
  end

  def admin_https_request(headers = {})
    Typhoeus.get("https://127.0.0.1:9081/admin/login", keyless_http_options.deep_merge(:headers => headers))
  end

  def admin_http_request(headers = {})
    Typhoeus.get("http://127.0.0.1:9080/admin/login", keyless_http_options.deep_merge(:headers => headers))
  end

  def admin_oauth2_https_request(headers = {})
    Typhoeus.get("https://127.0.0.1:9081/admins/auth/google_oauth2", keyless_http_options.deep_merge(:headers => headers))
  end

  def admin_oauth2_http_request(headers = {})
    Typhoeus.get("http://127.0.0.1:9080/admins/auth/google_oauth2", keyless_http_options.deep_merge(:headers => headers))
  end

  def website_https_request(headers = {})
    Typhoeus.get("https://127.0.0.1:9081/", keyless_http_options.deep_merge(:headers => headers))
  end

  def website_http_request(headers = {})
    Typhoeus.get("http://127.0.0.1:9080/", keyless_http_options.deep_merge(:headers => headers))
  end

  def website_signup_https_request(headers = {})
    Typhoeus.get("https://127.0.0.1:9081/signup/", keyless_http_options.deep_merge(:headers => headers))
  end

  def website_signup_http_request(headers = {})
    Typhoeus.get("http://127.0.0.1:9080/signup/", keyless_http_options.deep_merge(:headers => headers))
  end
end
