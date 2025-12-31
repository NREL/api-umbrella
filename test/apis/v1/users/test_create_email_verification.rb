require_relative "../../../test_helper"

class Test::Apis::V1::Users::TestCreateEmailVerification < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_not_email_verified_by_default
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(non_admin_key_creator_api_key).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :user => FactoryBot.attributes_for(:api_user) },
    }))
    assert_response_code(201, response)

    data = MultiJson.load(response.body)
    assert_kind_of(String, data["user"]["api_key"])
    user = ApiUser.find(data["user"]["id"])
    assert_equal(false, user.email_verified)
  end

  def test_verify_email_explicit_false
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(non_admin_key_creator_api_key).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => {
        :user => FactoryBot.attributes_for(:api_user),
        :options => { :verify_email => false },
      },
    }))
    assert_response_code(201, response)

    data = MultiJson.load(response.body)
    assert_kind_of(String, data["user"]["api_key"])
    user = ApiUser.find(data["user"]["id"])
    assert_equal(false, user.email_verified)
  end

  def test_email_verification_does_not_return_key
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(non_admin_key_creator_api_key).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => {
        :user => FactoryBot.attributes_for(:api_user),
        :options => { :verify_email => true },
      },
    }))
    assert_response_code(201, response)

    data = MultiJson.load(response.body)
    assert_nil(data["user"]["api_key"])
    user = ApiUser.find(data["user"]["id"])
    assert_equal(true, user.email_verified)
    refute_match(user.api_key, response.body)
  end

  def test_email_verified_when_admin_creates_account
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => { :user => FactoryBot.attributes_for(:api_user) },
    }))
    assert_response_code(201, response)

    data = MultiJson.load(response.body)
    assert_kind_of(String, data["user"]["api_key"])
    user = ApiUser.find(data["user"]["id"])
    assert_equal(true, user.email_verified)
  end

  def test_email_verified_explicit_true_when_admin_creates_account
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => {
        :user => FactoryBot.attributes_for(:api_user),
        :options => { :verify_email => true },
      },
    }))
    assert_response_code(201, response)

    data = MultiJson.load(response.body)
    assert_kind_of(String, data["user"]["api_key"])
    user = ApiUser.find(data["user"]["id"])
    assert_equal(true, user.email_verified)
  end

  def test_email_verified_can_be_disabled_when_admin_creates_account
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => {
        :user => FactoryBot.attributes_for(:api_user),
        :options => { :verify_email => false },
      },
    }))
    assert_response_code(201, response)

    data = MultiJson.load(response.body)
    assert_kind_of(String, data["user"]["api_key"])
    user = ApiUser.find(data["user"]["id"])
    assert_equal(false, user.email_verified)
  end

  private

  def non_admin_key_creator_api_key
    user = FactoryBot.create(:api_user, {
      :roles => ["api-umbrella-key-creator"],
    })

    { :headers => { "X-Api-Key" => user.api_key } }
  end
end
