require_relative "../../test_helper"

class Test::Proxy::Caching::TestStripResponseCookies < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::Caching

  def setup
    super
    setup_server
  end

  def test_does_not_cache_responses_with_google_analytics_cookie
    refute_cacheable("/api/cacheable-set-cookie/", {
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump({
        "set_cookies" => [
          "__utma=foo",
        ],
      }),
    })

    refute_cacheable("/api/cacheable-set-cookie/", {
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump({
        "set_cookies" => [
          "_ga=foo",
        ],
      }),
    })
  end

  def test_does_not_cache_responses_with_any_cookie
    refute_cacheable("/api/cacheable-set-cookie/", {
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump({
        "set_cookies" => [
          "foo=bar",
        ],
      }),
    })
  end

  def test_stripped_cookies_can_be_configured
    refute_cacheable("/api/cacheable-set-cookie/", {
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump({
        "set_cookies" => [
          "foo0=bar",
        ],
      }),
    })

    refute_cacheable("/api/cacheable-set-cookie/", {
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump({
        "set_cookies" => [
          "foo0=bar",
          "foo1=bar",
        ],
      }),
    })

    refute_cacheable("/api/cacheable-set-cookie/", {
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump({
        "set_cookies" => [
          "Expires=a3fWa; Expires=Wed, 21 Oct 2015 07:28:00 GMT",
        ],
      }),
    })

    refute_cacheable("/api/cacheable-set-cookie/", {
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump({
        "set_cookies" => [
          "fooa=a3fWa; Expires=Wed, 21 Oct 2015 07:28:00 GMT",
        ],
      }),
    })

    refute_cacheable("/api/cacheable-set-cookie/", {
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump({
        "set_cookies" => [
          "fooa=bar",
        ],
      }),
    })

    refute_cacheable("/api/cacheable-set-cookie/", {
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump({
        "set_cookies" => [
          "foo0=bar",
          "fooa=bar",
        ],
      }),
    })

    override_config({
      "strip_response_cookies" => [
        "^foo[0-9]$",
        "^Expires$",
      ],
    }) do
      assert_cacheable("/api/cacheable-set-cookie/", {
        :headers => { "Content-Type" => "application/json" },
        :body => MultiJson.dump({
          "set_cookies" => [
            "foo0=bar",
          ],
        }),
      })

      assert_cacheable("/api/cacheable-set-cookie/", {
        :headers => { "Content-Type" => "application/json" },
        :body => MultiJson.dump({
          "set_cookies" => [
            "foo0=bar",
            "foo1=bar",
          ],
        }),
      })

      assert_cacheable("/api/cacheable-set-cookie/", {
        :headers => { "Content-Type" => "application/json" },
        :body => MultiJson.dump({
          "set_cookies" => [
            "Expires=a3fWa; Expires=Wed, 21 Oct 2015 07:28:00 GMT",
          ],
        }),
      })

      refute_cacheable("/api/cacheable-set-cookie/", {
        :headers => { "Content-Type" => "application/json" },
        :body => MultiJson.dump({
          "set_cookies" => [
            "fooa=a3fWa; Expires=Wed, 21 Oct 2015 07:28:00 GMT",
          ],
        }),
      })

      refute_cacheable("/api/cacheable-set-cookie/", {
        :headers => { "Content-Type" => "application/json" },
        :body => MultiJson.dump({
          "set_cookies" => [
            "fooa=bar",
          ],
        }),
      })

      refute_cacheable("/api/cacheable-set-cookie/", {
        :headers => { "Content-Type" => "application/json" },
        :body => MultiJson.dump({
          "set_cookies" => [
            "foo0=bar",
            "fooa=bar",
          ],
        }),
      })

      # Strips all cookies when all cookies eligible for stripping.
      response = Typhoeus.get("http://127.0.0.1:9080/api/cacheable-set-cookie/", http_options.deep_merge({
        :params => {
          :unique_test_id => "#{unique_test_id}-#{next_unique_number}",
        },
        :headers => { "Content-Type" => "application/json" },
        :body => MultiJson.dump({
          "set_cookies" => [
            "foo0=bar",
            "foo1=bar",
            "Expires=bar",
          ],
        }),
      }))
      assert_nil(response.headers["Set-Cookie"])

      # Strips no cookies when at least 1 cookie won't be stripped.
      response = Typhoeus.get("http://127.0.0.1:9080/api/cacheable-set-cookie/", http_options.deep_merge({
        :params => {
          :unique_test_id => "#{unique_test_id}-#{next_unique_number}",
        },
        :headers => { "Content-Type" => "application/json" },
        :body => MultiJson.dump({
          "set_cookies" => [
            "foo0=bar",
            "fooa=bar",
          ],
        }),
      }))
      assert_equal([
        "foo0=bar",
        "fooa=bar",
      ], response.headers["Set-Cookie"])

      # Parses cookies with commas in the argument values.
      response = Typhoeus.get("http://127.0.0.1:9080/api/cacheable-set-cookie/", http_options.deep_merge({
        :params => {
          :unique_test_id => "#{unique_test_id}-#{next_unique_number}",
        },
        :headers => { "Content-Type" => "application/json" },
        :body => MultiJson.dump({
          "set_cookies" => [
            "foo=a3fWa; Expires=Wed, 21 Oct 2015 07:28:00 GMT",
          ],
        }),
      }))
      assert_equal("foo=a3fWa; Expires=Wed, 21 Oct 2015 07:28:00 GMT", response.headers["Set-Cookie"])
    end
  end
end
