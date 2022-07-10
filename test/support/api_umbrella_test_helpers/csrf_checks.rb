require "support/api_umbrella_test_helpers/admin_auth"

module ApiUmbrellaTestHelpers
  module CsrfChecks
    include ApiUmbrellaTestHelpers::AdminAuth

    private

    def assert_csrf_token_optional(url:, method: :get)
      assert_session_no_csrf_token(url: url, method: method)
      assert_session_with_csrf_token(url: url, method: method)
      assert_admin_token_no_csrf_token(url: url, method: method)
    end

    def assert_csrf_token_required_for_session(url:, method: :get)
      refute_session_no_csrf_token(url: url, method: method)
      assert_session_with_csrf_token(url: url, method: method)
      assert_admin_token_no_csrf_token(url: url, method: method)
    end

    def assert_session_no_csrf_token(url:, method:)
      url = url.call if url.respond_to?(:call)
      response = Typhoeus::Request.new(url, {
        :method => method,
      }.deep_merge(session_no_csrf_token)).run
      assert_response_csrf(response)
    end

    def refute_session_no_csrf_token(url:, method:)
      url = url.call if url.respond_to?(:call)
      response = Typhoeus::Request.new(url, {
        :method => method,
      }.deep_merge(session_no_csrf_token)).run
      refute_response_csrf(response)
    end

    def assert_session_with_csrf_token(url:, method:)
      url = url.call if url.respond_to?(:call)
      response = Typhoeus::Request.new(url, {
        :method => method,
      }.deep_merge(session_with_csrf_token)).run
      assert_response_csrf(response)
    end

    def assert_admin_token_no_csrf_token(url:, method:)
      url = url.call if url.respond_to?(:call)
      response = Typhoeus::Request.new(url, {
        :method => method,
      }.deep_merge(admin_token_no_csrf_token)).run
      assert_response_csrf(response)
    end

    def session_no_csrf_token
      options = http_options.deep_merge(admin_session)
      assert_nil(options.fetch(:headers)["X-CSRF-Token"])
      options
    end

    def session_with_csrf_token
      options = http_options.deep_merge(admin_csrf_session)
      assert_kind_of(String, options.fetch(:headers).fetch("X-CSRF-Token"))
      options
    end

    def admin_token_no_csrf_token
      options = http_options.deep_merge(admin_token)
      assert_nil(options.fetch(:headers)["X-CSRF-Token"])
      options
    end

    def assert_response_csrf(response)
      case response.code
      when 200
        assert_response_code(200, response)
      when 201
        assert_response_code(201, response)
      when 204
        assert_response_code(204, response)
      else
        assert_response_code(422, response)
        refute_match("Unprocessable Entity", response.body)
      end
    end

    def refute_response_csrf(response)
      assert_response_code(422, response)
      data = MultiJson.load(response.body)
      assert_equal({
        "error" => "Unprocessable Entity",
      }, data)
    end
  end
end
