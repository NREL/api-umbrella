require_relative "../../../test_helper"

class Test::Apis::V1::Users::TestCreateRecaptchaV2 < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup
  include Minitest::Hooks

  def setup
    super
    setup_server
    once_per_class_setup do
      override_config_set({
        "web" => {
          "recaptcha_scheme" => "http",
          "recaptcha_host" => "127.0.0.1",
          "recaptcha_port" => 9444,
          "recaptcha_v2_secret_key" => "foobar",
          "recaptcha_v2_required" => true,
        },
      })
    end
  end

  def after_all
    super
    override_config_reset
  end

  def test_successful_recaptcha_response
    set_recaptcha_mock({
      "success" => true,
      "challenge_ts" => "2023-12-01T20:15:43Z",
      "hostname" => "127.0.0.1",
    })

    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(non_admin_key_creator_api_key).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump({
        :user => FactoryBot.attributes_for(:api_user),
        "g-recaptcha-response-v2" => "foobar",
      }),
    }))
    assert_response_code(201, response)
    data = MultiJson.load(response.body)
    user = ApiUser.find(data["user"]["id"])
    assert_equal(true, user.registration_recaptcha_v2_success)
    assert_nil(user.registration_recaptcha_v2_error_codes)
    assert_equal("127.0.0.1", user.registration_recaptcha_v2_hostname)
  end

  def test_rejects_unsuccessful_recaptcha_response
    set_recaptcha_mock({
      "success" => false,
      "error-codes" => ["timeout-or-duplicate"],
    })

    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(non_admin_key_creator_api_key).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump({
        :user => FactoryBot.attributes_for(:api_user),
        "g-recaptcha-response-v2" => "foobar",
      }),
    }))
    assert_recaptcha_rejected(response)
  end

  def test_allows_unsuccessful_recaptcha_response_for_admins
    set_recaptcha_mock({
      "success" => false,
      "error-codes" => ["timeout-or-duplicate"],
    })

    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump({
        :user => FactoryBot.attributes_for(:api_user),
        "g-recaptcha-response-v2" => "foobar",
      }),
    }))
    assert_response_code(201, response)
    data = MultiJson.load(response.body)
    user = ApiUser.find(data["user"]["id"])
    assert_equal(false, user.registration_recaptcha_v2_success)
    assert_equal(["timeout-or-duplicate"], user.registration_recaptcha_v2_error_codes)
    assert_nil(user.registration_recaptcha_v2_hostname)
  end

  def test_rejects_missing_recaptcha_input
    set_recaptcha_mock({
      "success" => true,
    })

    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(non_admin_key_creator_api_key).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump({
        :user => FactoryBot.attributes_for(:api_user),
      }),
    }))
    assert_recaptcha_rejected(response)
  end

  def test_allows_missing_recaptcha_input_for_admins
    set_recaptcha_mock({
      "success" => false,
      "error-codes" => ["timeout-or-duplicate"],
    })

    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump({
        :user => FactoryBot.attributes_for(:api_user),
      }),
    }))
    assert_response_code(201, response)
    data = MultiJson.load(response.body)
    user = ApiUser.find(data["user"]["id"])
    assert_nil(user.registration_recaptcha_v2_success)
    assert_nil(user.registration_recaptcha_v2_error_codes)
    assert_nil(user.registration_recaptcha_v2_hostname)
  end

  def test_rejects_failed_recaptcha_response
    set_recaptcha_mock("", status: 500)

    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(non_admin_key_creator_api_key).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump({
        :user => FactoryBot.attributes_for(:api_user),
        "g-recaptcha-response-v2" => "foobar",
      }),
    }))
    assert_recaptcha_rejected(response)
  end

  def test_rejects_invalid_recaptcha_response
    set_recaptcha_mock("abc,123")

    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(non_admin_key_creator_api_key).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump({
        :user => FactoryBot.attributes_for(:api_user),
        "g-recaptcha-response-v2" => "foobar",
      }),
    }))
    assert_recaptcha_rejected(response)
  end

  def test_performs_domain_validation_based_on_allowed_domain_logic
    set_recaptcha_mock({
      "success" => true,
      "challenge_ts" => "2023-12-01T20:15:43Z",
      "hostname" => unique_test_hostname,
    })

    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(non_admin_key_creator_api_key).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump({
        :user => FactoryBot.attributes_for(:api_user),
        "g-recaptcha-response-v2" => "foobar",
      }),
    }))
    assert_recaptcha_rejected(response)

    prepend_api_backends([
      {
        :frontend_host => unique_test_hostname,
        :backend_host => "127.0.0.1",
        :servers => [{ :host => "127.0.0.1", :port => 9444 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/", :backend_prefix => "/" }],
      },
    ]) do
      response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(non_admin_key_creator_api_key).deep_merge({
        :headers => { "Content-Type" => "application/json" },
        :body => MultiJson.dump({
          :user => FactoryBot.attributes_for(:api_user),
          "g-recaptcha-response-v2" => "foobar",
        }),
      }))
      assert_response_code(201, response)
      data = MultiJson.load(response.body)
      user = ApiUser.find(data["user"]["id"])
      assert_equal(true, user.registration_recaptcha_v2_success)
      assert_nil(user.registration_recaptcha_v2_error_codes)
      assert_equal(unique_test_hostname, user.registration_recaptcha_v2_hostname)
    end
  end

  def test_optional_when_only_required_for_certain_origins
    set_recaptcha_mock({
      "success" => false,
      "error-codes" => ["timeout-or-duplicate"],
    })

    override_config_merge({
      "web" => {
        "recaptcha_v2_required_origin_regex" => "^(?!https://example.com|https://bar.example.com)",
      },
    }) do
      # Origin *not* requiring recaptcha.
      response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(non_admin_key_creator_api_key).deep_merge({
        :headers => {
          "Content-Type" => "application/json",
          "Origin" => "https://example.com",
        },
        :body => MultiJson.dump({
          :user => FactoryBot.attributes_for(:api_user),
          "g-recaptcha-response-v2" => "foobar",
        }),
      }))
      assert_response_code(201, response)
      data = MultiJson.load(response.body)
      user = ApiUser.find(data["user"]["id"])
      assert_equal(false, user.registration_recaptcha_v2_success)
      assert_equal(["timeout-or-duplicate"], user.registration_recaptcha_v2_error_codes)
      assert_nil(user.registration_recaptcha_v2_hostname)

      # Origin *not* requiring recaptcha.
      response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(non_admin_key_creator_api_key).deep_merge({
        :headers => {
          "Content-Type" => "application/json",
          "Origin" => "https://bar.example.com",
        },
        :body => MultiJson.dump({
          :user => FactoryBot.attributes_for(:api_user),
          "g-recaptcha-response-v2" => "foobar",
        }),
      }))
      assert_response_code(201, response)
      data = MultiJson.load(response.body)
      user = ApiUser.find(data["user"]["id"])
      assert_equal(false, user.registration_recaptcha_v2_success)
      assert_equal(["timeout-or-duplicate"], user.registration_recaptcha_v2_error_codes)
      assert_nil(user.registration_recaptcha_v2_hostname)

      # Origin requiring recaptcha.
      response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(non_admin_key_creator_api_key).deep_merge({
        :headers => {
          "Content-Type" => "application/json",
          "Origin" => "https://foo.example.com",
        },
        :body => MultiJson.dump({
          :user => FactoryBot.attributes_for(:api_user),
          "g-recaptcha-response-v2" => "foobar",
        }),
      }))
      assert_recaptcha_rejected(response)

      # Origin requiring recaptcha as admin
      response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(admin_token).deep_merge({
        :headers => {
          "Content-Type" => "application/json",
          "Origin" => "https://foo.example.com",
        },
        :body => MultiJson.dump({
          :user => FactoryBot.attributes_for(:api_user),
          "g-recaptcha-response-v2" => "foobar",
        }),
      }))
      assert_response_code(201, response)
      data = MultiJson.load(response.body)
      user = ApiUser.find(data["user"]["id"])
      assert_equal(false, user.registration_recaptcha_v2_success)
      assert_equal(["timeout-or-duplicate"], user.registration_recaptcha_v2_error_codes)
      assert_nil(user.registration_recaptcha_v2_hostname)

      # Missing origin, requiring recaptcha.
      response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(non_admin_key_creator_api_key).deep_merge({
        :headers => {
          "Content-Type" => "application/json",
        },
        :body => MultiJson.dump({
          :user => FactoryBot.attributes_for(:api_user),
          "g-recaptcha-response-v2" => "foobar",
        }),
      }))
      assert_recaptcha_rejected(response)
    end
  end

  private

  def non_admin_key_creator_api_key
    @non_admin_key_creator_api_user = FactoryBot.create(:api_user, {
      :roles => ["api-umbrella-key-creator"],
    })

    { :headers => { "X-Api-Key" => @non_admin_key_creator_api_user.api_key } }
  end

  def set_recaptcha_mock(body, status: 200)
    response = Typhoeus.get("http://127.0.0.1:9444/recaptcha/api/siteverify/set-mock", http_options.deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump({
        "status" => status,
        "body" => body.kind_of?(String) ? body : MultiJson.dump(body),
      }),
    }))
    assert_response_code(200, response)
  end

  def assert_recaptcha_rejected(response)
    assert_response_code(422, response)
    data = MultiJson.load(response.body)
    assert_equal({
      "errors" => [{
        "code" => "UNEXPECTED_ERROR",
        "message" => "CAPTCHA verification failed. Please try again or contact us for assistance.",
      }],
    }, data)
  end
end
