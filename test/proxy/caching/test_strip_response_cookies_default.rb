require_relative "../../test_helper"

class Test::Proxy::Caching::TestStripResponseCookiesDefault < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::Caching

  def setup
    super
    setup_server
  end

  def test_does_not_cache_responses_with_google_analytics_utm_cookie
    refute_cacheable("/api/cacheable-set-cookie/", {
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump({
        "set_cookies" => [
          "__utma=foo",
        ],
      }),
    })
  end

  def test_does_not_cache_responses_with_google_analytics_ga_cookie
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
end
