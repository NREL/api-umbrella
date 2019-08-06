require_relative "../test_helper"

class Test::Proxy::TestRefererValidation < Minitest::Test
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
          :url_matches => [{ :frontend_prefix => "/#{unique_test_class_id}/required-referers/", :backend_prefix => "/" }],
          :settings => {
            :allowed_referers => [
              "*.example.com*",
              "https://google.com/",
            ],
          },
          :sub_settings => [
            {
              :http_method => "any",
              :regex => "^/hello/sub-settings",
              :settings => {
                :allowed_referers => [
                  "*.foobar.com/*",
                ],
              },
            },
          ],
        },
        {
          :frontend_host => "127.0.0.1",
          :backend_host => "127.0.0.1",
          :servers => [{ :host => "127.0.0.1", :port => 9444 }],
          :url_matches => [{ :frontend_prefix => "/#{unique_test_class_id}/empty-array-referers/", :backend_prefix => "/" }],
          :settings => {
            :allowed_referers => [],
          },
        },
      ])

      @@user_with_allowed_referers = FactoryBot.create(:api_user, {
        :settings => FactoryBot.build(:api_user_settings, {
          :rate_limit_mode => "unlimited",
          :allowed_referers => [
            "*.example.com/specific*",
            "https://google.com/specific",
            "*.yahoo.com/*",
          ],
        }),
      })
    end
  end

  def test_required_unauthorized
    assert_unauthorized_referer("/#{unique_test_class_id}/required-referers/hello", {
      "Referer" => "http://www.foobar.com/",
    })
  end

  def test_required_unauthorized_no_referer
    assert_unauthorized_referer("/#{unique_test_class_id}/required-referers/hello")
  end

  def test_required_authorized_exact_match
    assert_authorized_referer("/#{unique_test_class_id}/required-referers/hello", {
      "Referer" => "https://google.com/",
    })
  end

  def test_required_authorized_case_insensitive
    assert_authorized_referer("/#{unique_test_class_id}/required-referers/hello", {
      "Referer" => "hTtPs://GOOGLE.COM/",
    })
  end

  def test_required_unauthorized_exact_match
    assert_unauthorized_referer("/#{unique_test_class_id}/required-referers/hello", {
      "Referer" => "https://google.com/extra",
    }, :origin_authorized => true)
  end

  def test_required_authorized_wildcard_match
    assert_authorized_referer("/#{unique_test_class_id}/required-referers/hello", {
      "Referer" => "http://www.example.com/testing",
    })
  end

  def test_required_unauthorized_wildcard_match
    assert_unauthorized_referer("/#{unique_test_class_id}/required-referers/hello", {
      "Referer" => "http://example.com/testing",
    })
  end

  def test_required_authorized_origin_fallback
    assert_authorized_referer("/#{unique_test_class_id}/required-referers/hello", {
      "Origin" => "http://www.example.com",
    })
  end

  def test_default_authorized_no_referer
    assert_authorized_referer("/api/hello")
  end

  def test_default_authorized_any_referer
    assert_authorized_referer("/api/hello", {
      "Referer" => "http://www.testing.com/",
    })
  end

  def test_empty_array_authorized_no_referer
    assert_authorized_referer("/#{unique_test_class_id}/empty-array-referers/hello")
  end

  def test_empty_array_authorized_any_referer
    assert_authorized_referer("/#{unique_test_class_id}/empty-array-referers/hello", {
      "Referer" => "http://www.testing.com/",
    })
  end

  def test_sub_url_settings_overrides_parent_settings
    assert_unauthorized_referer("/#{unique_test_class_id}/required-referers/hello/sub-settings", {
      "Referer" => "http://www.example.com/testing",
    })
    assert_authorized_referer("/#{unique_test_class_id}/required-referers/hello/sub-settings", {
      "Referer" => "http://www.foobar.com/",
    })
  end

  def test_user_authorized_when_user_and_api_both_allow
    assert_authorized_referer("/#{unique_test_class_id}/required-referers/hello", {
      "X-Api-Key" => @@user_with_allowed_referers.api_key,
      "Referer" => "http://www.example.com/specificstuff",
    })
  end

  def test_user_unauthorized_when_user_or_api_dont_allow_wildcard
    assert_unauthorized_referer("/#{unique_test_class_id}/required-referers/hello", {
      "X-Api-Key" => @@user_with_allowed_referers.api_key,
      "Referer" => "http://www.example.com/testing",
    }, :origin_authorized => true)
  end

  def test_user_unauthorized_when_user_or_api_dont_allow_exact
    assert_unauthorized_referer("/#{unique_test_class_id}/required-referers/hello", {
      "X-Api-Key" => @@user_with_allowed_referers.api_key,
      "Referer" => "https://google.com/specific",
    }, :origin_authorized => true)
  end

  def test_user_authorized_when_user_allows_no_api_settings
    assert_authorized_referer("/api/hello", {
      "X-Api-Key" => @@user_with_allowed_referers.api_key,
      "Referer" => "http://www.yahoo.com/",
    })
  end

  def test_user_unauthorized_when_user_disallows_no_api_settings
    assert_unauthorized_referer("/api/hello", {
      "X-Api-Key" => @@user_with_allowed_referers.api_key,
      "Referer" => "http://www.bing.com/",
    })
  end

  def test_user_authorized_when_empty_array
    user = FactoryBot.create(:api_user, {
      :settings => FactoryBot.build(:api_user_settings, {
        :rate_limit_mode => "unlimited",
        :allowed_referers => [],
      }),
    })

    assert_authorized_referer("/api/hello", {
      "X-Api-Key" => user.api_key,
      "Referer" => "http://www.foobar.com/",
    })

    assert_authorized_referer("/#{unique_test_class_id}/required-referers/hello/sub-settings", {
      "X-Api-Key" => user.api_key,
      "Referer" => "http://www.foobar.com/",
    })
  end

  def test_referer_takes_precedence_over_origin
    assert_authorized_referer("/#{unique_test_class_id}/required-referers/hello", {
      "Origin" => "https://google.com",
      "Referer" => "https://google.com/extra",
    })

    assert_unauthorized_referer("/#{unique_test_class_id}/required-referers/hello", {
      "Origin" => "https://bing.com",
      "Referer" => "https://google.com/extra",
    })

    assert_authorized_referer("/#{unique_test_class_id}/required-referers/hello", {
      "Origin" => "https://google.com",
      "Referer" => "https://google.com/",
    })

    assert_authorized_referer("/#{unique_test_class_id}/required-referers/hello", {
      "Origin" => "https://bing.com",
      "Referer" => "https://google.com/",
    })
  end

  def test_origin_fallback_excludes_path_matching
    assert_authorized_referer("/#{unique_test_class_id}/required-referers/hello", {
      "Origin" => "https://google.com",
    })

    assert_unauthorized_referer("/#{unique_test_class_id}/required-referers/hello", {
      "Referer" => "https://google.com",
      "Origin" => nil,
    })

    assert_authorized_referer("/#{unique_test_class_id}/required-referers/hello/sub-settings", {
      "Origin" => "http://foo.foobar.com",
    })

    assert_unauthorized_referer("/#{unique_test_class_id}/required-referers/hello/sub-settings", {
      "Referer" => "http://foo.foobar.com",
      "Origin" => nil,
    })

    assert_authorized_referer("/#{unique_test_class_id}/required-referers/hello", {
      "X-Api-Key" => @@user_with_allowed_referers.api_key,
      "Origin" => "http://www.example.com",
    })

    assert_unauthorized_referer("/#{unique_test_class_id}/required-referers/hello", {
      "X-Api-Key" => @@user_with_allowed_referers.api_key,
      "Referer" => "http://www.example.com",
      "Origin" => nil,
    })
  end

  private

  def assert_unauthorized_referer(path, headers = {}, origin_authorized: false)
    response = Typhoeus.get("http://127.0.0.1:9080#{path}", http_options.deep_merge({
      :headers => headers,
    }))
    assert_response_code(403, response)
    assert_match("API_KEY_UNAUTHORIZED", response.body)

    if headers && headers.key?("Referer") && !headers.key?("Origin")
      uri = Addressable::URI.parse(headers["Referer"])
      uri.path = nil
      uri.query = nil
      origin = uri.to_s

      response = Typhoeus.get("http://127.0.0.1:9080#{path}", http_options.deep_merge({
        :headers => headers.deep_merge({
          "Origin" => origin,
        }),
      }))
      if origin_authorized
        assert_response_code(200, response)
      else
        assert_response_code(403, response)
        assert_match("API_KEY_UNAUTHORIZED", response.body)
      end

      response = Typhoeus.get("http://127.0.0.1:9080#{path}", http_options.deep_merge({
        :headers => headers.except("Referer").deep_merge({
          "Origin" => origin,
        }),
      }))
      if origin_authorized
        assert_response_code(200, response)
      else
        assert_response_code(403, response)
        assert_match("API_KEY_UNAUTHORIZED", response.body)
      end
    end
  end

  def assert_authorized_referer(path, headers = {})
    response = Typhoeus.get("http://127.0.0.1:9080#{path}", http_options.deep_merge({
      :headers => headers,
    }))
    assert_response_code(200, response)

    if headers && headers.key?("Referer") && !headers.key?("Origin")
      uri = Addressable::URI.parse(headers["Referer"])
      uri.path = nil
      uri.query = nil
      origin = uri.to_s

      response = Typhoeus.get("http://127.0.0.1:9080#{path}", http_options.deep_merge({
        :headers => headers.deep_merge({
          "Origin" => origin,
        }),
      }))
      assert_response_code(200, response)

      response = Typhoeus.get("http://127.0.0.1:9080#{path}", http_options.deep_merge({
        :headers => headers.except("Referer").deep_merge({
          "Origin" => origin,
        }),
      }))
      assert_response_code(200, response)
    end
  end
end
