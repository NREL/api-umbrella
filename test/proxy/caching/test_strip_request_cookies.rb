require_relative "../../test_helper"

class Test::Proxy::Caching::TestStripRequestCookies < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::Caching

  def setup
    super
    setup_server
  end

  def test_caches_requests_with_google_analytics_utm_cookie
    assert_cacheable("/api/cacheable-cache-control-max-age/", :headers => {
      "Cookie" => "__utma=foo",
    })
  end

  def test_caches_requests_with_google_analytics_ga_cookie
    assert_cacheable("/api/cacheable-cache-control-max-age/", :headers => {
      "Cookie" => "_ga=foo",
    })
  end

  def test_caches_requests_with_crazyegg_analytics_cookie
    assert_cacheable("/api/cacheable-cache-control-max-age/", :headers => {
      "Cookie" => "is_returning=foo",
    })
  end

  def test_does_not_cache_requests_with_non_exact_cookie_match
    refute_cacheable("/api/cacheable-cache-control-max-age/", :headers => {
      "Cookie" => "__ga=foo",
    })
  end

  def test_stripped_cookies_can_be_configured
    refute_cacheable("/api/cacheable-cache-control-max-age/", {
      :params => {
        :unique_test_id => "#{unique_test_id}-#{next_unique_number}",
      },
      :headers => {
        "Cookie" => "foo0=bar",
      },
    })

    refute_cacheable("/api/cacheable-cache-control-max-age/", {
      :params => {
        :unique_test_id => "#{unique_test_id}-#{next_unique_number}",
      },
      :headers => {
        "Cookie" => "fooa=bar",
      },
    })

    override_config({
      "strip_cookies" => [
        "^foo[0-9]$",
      ],
    }) do
      assert_cacheable("/api/cacheable-cache-control-max-age/", {
        :params => {
          :unique_test_id => "#{unique_test_id}-#{next_unique_number}",
        },
        :headers => {
          "Cookie" => "foo0=bar",
        },
      })

      refute_cacheable("/api/cacheable-cache-control-max-age/", {
        :params => {
          :unique_test_id => "#{unique_test_id}-#{next_unique_number}",
        },
        :headers => {
          "Cookie" => "fooa=bar",
        },
      })
    end
  end
end
