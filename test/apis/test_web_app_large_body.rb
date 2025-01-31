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

    response = nil
    100.times do
      response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users/#{user.id}.json", http_options.deep_merge(admin_token).deep_merge({
        :headers => { "Content-Type" => "application/json" },
        :body => body,
      }))
      ap response.code
    end
    assert_response_code(413, response)

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
      assert_response_code(413, response)

      user.reload
      assert_equal(4001, user.settings.allowed_referers.length)
    end
  end
end
