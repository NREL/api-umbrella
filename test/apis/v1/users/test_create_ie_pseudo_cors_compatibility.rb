require_relative "../../../test_helper"

# Make sure our API key creation endpoint can be successfully called with
# IE8-9's shimmed pseudo-CORS support. This ensures API keys can be created
# even if the endpoint is called with empty or text/plain content-types. See
# ApplicationController#parse_post_for_pseudo_ie_cors for more detail.
class Test::Apis::V1::Users::TestCreateIePseudoCorsCompatibility < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup
  parallelize_me!

  def setup
    super
    setup_server

    @attributes = {
      :first_name => "Mr",
      :last_name => "Potato",
      :email => "potato@example.com",
      :use_description => "",
      :terms_and_conditions => "1",
    }
  end

  def test_content_type_null
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(non_admin_auth).deep_merge({
      :headers => { "Content-Type" => nil },
      :body => { :user => @attributes },
    }))
    assert_response_code(201, response)
    data = MultiJson.load(response.body)
    assert_equal("Potato", data["user"]["last_name"])
  end

  def test_content_type_empty
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(non_admin_auth).deep_merge(empty_http_header_options("Content-Type")).deep_merge({
      :body => { :user => @attributes },
    }))
    assert_response_code(201, response)
    data = MultiJson.load(response.body)
    assert_equal("Potato", data["user"]["last_name"])
  end

  def test_content_type_text_plain
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(non_admin_auth).deep_merge({
      :headers => { "Content-Type" => "text/plain" },
      :body => { :user => @attributes },
    }))
    assert_response_code(201, response)
    data = MultiJson.load(response.body)
    assert_equal("Potato", data["user"]["last_name"])
  end

  private

  def non_admin_auth
    user = FactoryBot.create(:api_user, {
      :roles => ["api-umbrella-key-creator"],
    })

    { :headers => { "X-Api-Key" => user.api_key } }
  end
end
