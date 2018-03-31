require_relative "../../test_helper"

class Test::Proxy::ApiKeyValidation::TestEmailVerification < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  parallelize_me!

  def setup
    super
    setup_server
    once_per_class_setup do
      prepend_api_backends([
        {
          :frontend_host => "127.0.0.1",
          :backend_host => "127.0.0.1",
          :servers => [{ :host => "127.0.0.1", :port => 9444 }],
          :url_matches => [{ :frontend_prefix => "/#{unique_test_class_id}/api-key-verification/", :backend_prefix => "/" }],
          :settings => {
            :disable_api_key => true,
            :rate_limit_mode => "unlimited",
          },
          :sub_settings => [
            {
              :http_method => "any",
              :regex => "^/hello/none",
              :settings => {
                :api_key_verification_level => "none",
              },
            },
            {
              :http_method => "any",
              :regex => "^/hello/transition_email",
              :settings => {
                :api_key_verification_level => "transition_email",
                :api_key_verification_transition_start_at => Time.iso8601("2013-02-01T01:27:00Z"),
              },
            },
            {
              :http_method => "any",
              :regex => "^/hello/required_email",
              :settings => {
                :api_key_verification_level => "required_email",
              },
            },
          ],
        },
      ])
    end
  end

  def test_verification_default_none_user_verified_false
    response = make_request("/#{unique_test_class_id}/api-key-verification/hello", :email_verified => false)
    assert_response_code(200, response)
    assert_equal("Hello World", response.body)
  end

  def test_verification_default_none_user_verified_true
    response = make_request("/#{unique_test_class_id}/api-key-verification/hello", :email_verified => true)
    assert_response_code(200, response)
    assert_equal("Hello World", response.body)
  end

  def test_verification_none_user_verified_false
    response = make_request("/#{unique_test_class_id}/api-key-verification/hello/none", :email_verified => false)
    assert_response_code(200, response)
    assert_equal("Hello World", response.body)
  end

  def test_verification_none_user_verified_true
    response = make_request("/#{unique_test_class_id}/api-key-verification/hello/none", :email_verified => true)
    assert_response_code(200, response)
    assert_equal("Hello World", response.body)
  end

  def test_verification_required_user_verified_false
    response = make_request("/#{unique_test_class_id}/api-key-verification/hello/required_email", :email_verified => false)
    assert_response_code(403, response)
    assert_match("API_KEY_UNVERIFIED", response.body)
  end

  def test_verification_required_user_verified_true
    response = make_request("/#{unique_test_class_id}/api-key-verification/hello/required_email", :email_verified => true)
    assert_response_code(200, response)
    assert_equal("Hello World", response.body)
  end

  def test_verification_transition_user_verified_false_created_before_transition_time
    response = make_request("/#{unique_test_class_id}/api-key-verification/hello/transition_email", :email_verified => false, :created_at => Time.iso8601("2013-02-01T01:26:59Z"))
    assert_response_code(200, response)
    assert_equal("Hello World", response.body)
  end

  def test_verification_transition_user_verified_false_created_after_transition_time
    response = make_request("/#{unique_test_class_id}/api-key-verification/hello/transition_email", :email_verified => false, :created_at => Time.iso8601("2013-02-01T01:27:00Z"))
    assert_response_code(403, response)
    assert_match("API_KEY_UNVERIFIED", response.body)
  end

  def test_verification_transition_user_verified_true_created_before_transition_time
    response = make_request("/#{unique_test_class_id}/api-key-verification/hello/transition_email", :email_verified => true, :created_at => Time.iso8601("2013-02-01T01:26:59Z"))
    assert_response_code(200, response)
    assert_equal("Hello World", response.body)
  end

  def test_verification_transition_user_verified_true_created_after_transition_time
    response = make_request("/#{unique_test_class_id}/api-key-verification/hello/transition_email", :email_verified => true, :created_at => Time.iso8601("2013-02-01T01:27:00.000Z"))
    assert_response_code(200, response)
    assert_equal("Hello World", response.body)
  end

  private

  def make_request(path, user_options)
    user = FactoryBot.create(:api_user, user_options)
    Typhoeus.get("http://127.0.0.1:9080#{path}", http_options.deep_merge({
      :headers => {
        "X-Api-Key" => user.api_key,
      },
    }))
  end
end
