require_relative "../test_helper"

class Test::Apis::TestWebAppLargeBody < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
  end

  def test_succeeds_with_large_body_below_default_limit
    user = FactoryBot.create(:api_user, {
      :settings => FactoryBot.build(:api_user_settings, {
        :allowed_referers => Array.new(2000) { SecureRandom.alphanumeric(500) },
      }),
    })

    attributes = user.as_json
    assert_equal(2000, attributes["settings"]["allowed_referers"].length)
    attributes["settings"]["allowed_referers"] << SecureRandom.alphanumeric(500)
    assert_equal(2001, attributes["settings"]["allowed_referers"].length)

    body = MultiJson.dump(:user => attributes)
    assert_operator(body.bytesize, :>, 0.9 * 1024 * 1024) # 0.9MB
    assert_operator(body.bytesize, :<, 1 * 1024 * 1024) # 1MB

    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/users/#{user.id}.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => body,
    }))
    assert_response_code(200, response)

    user.reload
    assert_equal(2001, user.settings.allowed_referers.length)
  end

  def test_fails_with_large_body_above_default_limit
    user = FactoryBot.create(:api_user, {
      :settings => FactoryBot.build(:api_user_settings, {
        :allowed_referers => Array.new(2200) { SecureRandom.alphanumeric(500) },
      }),
    })

    attributes = user.as_json
    assert_equal(2200, attributes["settings"]["allowed_referers"].length)
    attributes["settings"]["allowed_referers"] << SecureRandom.alphanumeric(500)
    assert_equal(2201, attributes["settings"]["allowed_referers"].length)

    body = MultiJson.dump(:user => attributes)
    assert_operator(body.bytesize, :>, 1 * 1024 * 1024) # 1MB
    assert_operator(body.bytesize, :<, 1.1 * 1024 * 1024) # 1.1MB

    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/users/#{user.id}.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => body,
    }))
    assert_above_max_body_size(response)

    user.reload
    assert_equal(2200, user.settings.allowed_referers.length)
  end

  def test_limit_is_configurable
    override_config({
      "web" => {
        "max_body_size" => "2m",
      },
    }) do
      user = FactoryBot.create(:api_user, {
        :settings => FactoryBot.build(:api_user_settings, {
          :allowed_referers => Array.new(4000) { SecureRandom.alphanumeric(500) },
        }),
      })

      attributes = user.as_json
      assert_equal(4000, attributes["settings"]["allowed_referers"].length)
      attributes["settings"]["allowed_referers"] << SecureRandom.alphanumeric(500)
      assert_equal(4001, attributes["settings"]["allowed_referers"].length)

      body = MultiJson.dump(:user => attributes)
      assert_operator(body.bytesize, :>, 1.9 * 1024 * 1024) # 1.9MB
      assert_operator(body.bytesize, :<, 2 * 1024 * 1024) # 2MB

      response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/users/#{user.id}.json", http_options.deep_merge(admin_token).deep_merge({
        :headers => { "Content-Type" => "application/json" },
        :body => body,
      }))
      assert_response_code(200, response)

      user.reload
      assert_equal(4001, user.settings.allowed_referers.length)

      attributes["settings"]["allowed_referers"] += Array.new(200) { SecureRandom.alphanumeric(500) }

      body = MultiJson.dump(:user => attributes)
      assert_operator(body.bytesize, :>, 2 * 1024 * 1024) # 2MB
      assert_operator(body.bytesize, :<, 2.1 * 1024 * 1024) # 2.1MB

      response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/users/#{user.id}.json", http_options.deep_merge(admin_token).deep_merge({
        :headers => { "Content-Type" => "application/json" },
        :body => body,
      }))
      assert_above_max_body_size(response)

      user.reload
      assert_equal(4001, user.settings.allowed_referers.length)
    end
  end

  private

  def assert_above_max_body_size(response)
    # Traffic Server will sometimes return a 502 instead of the original 413
    # since the underlying backend API cancelled the request before Traffic
    # Server fully sent it. While not ideal, this appears to have been present
    # to some degree for a while in Traffic Server. It didn't surface as
    # readily in Traffic Server 9.1 since it seemed to require more parallel
    # requests to occur, but it was still possible. In 9.2+ it happens more
    # frequently without parallel requests. See
    # Test::Proxy::TestUploads#test_mixed_uploads_stress_test and
    # https://github.com/apache/trafficserver/issues/10393.
    if response.code == 502
      assert_response_code(502, response)
    else
      assert_response_code(413, response)
    end
  end
end
