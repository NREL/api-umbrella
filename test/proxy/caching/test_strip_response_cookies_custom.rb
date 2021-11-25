require_relative "../../test_helper"

class Test::Proxy::Caching::TestStripResponseCookiesCustom < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::Caching
  include Minitest::Hooks

  def setup
    super
    setup_server

    once_per_class_setup do
      override_config_set({
        "strip_response_cookies" => [
          "^foo[0-9]$",
          "^bar[^ '\"]$",
          "^Expires$",
        ],
      })
    end
  end

  def after_all
    super
    override_config_reset
  end

  def test_strips_single_cookie
    assert_cacheable("/api/cacheable-set-cookie/", {
      :params => {
        :unique_test_id => "#{unique_test_id}-#{next_unique_number}",
      },
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump({
        "set_cookies" => [
          "foo0=bar",
        ],
      }),
    })
  end

  def test_strips_multiple_cookies
    assert_cacheable("/api/cacheable-set-cookie/", {
      :params => {
        :unique_test_id => "#{unique_test_id}-#{next_unique_number}",
      },
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump({
        "set_cookies" => [
          "foo0=bar",
          "foo1=bar",
        ],
      }),
    })
  end

  def test_cookie_name_not_matching_pattern
    refute_cacheable("/api/cacheable-set-cookie/", {
      :params => {
        :unique_test_id => "#{unique_test_id}-#{next_unique_number}",
      },
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump({
        "set_cookies" => [
          "fooa=bar",
        ],
      }),
    })
  end

  def test_strips_based_on_cookie_name_not_content
    assert_cacheable("/api/cacheable-set-cookie/", {
      :params => {
        :unique_test_id => "#{unique_test_id}-#{next_unique_number}",
      },
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump({
        "set_cookies" => [
          "Expires=a3fWa; Expires=Wed, 21 Oct 2015 07:28:00 GMT",
        ],
      }),
    })

    refute_cacheable("/api/cacheable-set-cookie/", {
      :params => {
        :unique_test_id => "#{unique_test_id}-#{next_unique_number}",
      },
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump({
        "set_cookies" => [
          "fooa=a3fWa; Expires=Wed, 21 Oct 2015 07:28:00 GMT",
        ],
      }),
    })
  end

  def test_strips_no_cookies_when_not_all_stripped
    set_cookies = [
      "foo0=bar",
      "fooa=bar",
    ]

    response = Typhoeus.get("http://127.0.0.1:9080/api/cacheable-set-cookie/", http_options.deep_merge({
      :params => {
        :unique_test_id => "#{unique_test_id}-#{next_unique_number}",
      },
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump({
        "set_cookies" => set_cookies,
      }),
    }))
    assert_equal([
      "foo0=bar",
      "fooa=bar",
    ], response.headers["Set-Cookie"])

    refute_cacheable("/api/cacheable-set-cookie/", {
      :params => {
        :unique_test_id => "#{unique_test_id}-#{next_unique_number}",
      },
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump({
        "set_cookies" => set_cookies,
      }),
    })
  end

  def test_strips_all_cookies_when_all_match
    set_cookies = [
      "foo0=bar",
      "foo1=bar",
      "Expires=bar",
    ]

    response = Typhoeus.get("http://127.0.0.1:9080/api/cacheable-set-cookie/", http_options.deep_merge({
      :params => {
        :unique_test_id => "#{unique_test_id}-#{next_unique_number}",
      },
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump({
        "set_cookies" => set_cookies,
      }),
    }))
    assert_nil(response.headers["Set-Cookie"])

    assert_cacheable("/api/cacheable-set-cookie/", {
      :params => {
        :unique_test_id => "#{unique_test_id}-#{next_unique_number}",
      },
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump({
        "set_cookies" => set_cookies,
      }),
    })
  end

  def test_parses_cookies_with_commas_in_value
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

  def test_regex_with_spaces_and_quotes
    set_cookies = [
      "bar0=bar",
    ]

    response = Typhoeus.get("http://127.0.0.1:9080/api/cacheable-set-cookie/", http_options.deep_merge({
      :params => {
        :unique_test_id => "#{unique_test_id}-#{next_unique_number}",
      },
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump({
        "set_cookies" => set_cookies,
      }),
    }))
    assert_nil(response.headers["Set-Cookie"])

    assert_cacheable("/api/cacheable-set-cookie/", {
      :params => {
        :unique_test_id => "#{unique_test_id}-#{next_unique_number}",
      },
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump({
        "set_cookies" => set_cookies,
      }),
    })
  end

  def test_matches_cookie_names_case_insensitively
    set_cookies = [
      "ExPiReS=bar",
    ]

    response = Typhoeus.get("http://127.0.0.1:9080/api/cacheable-set-cookie/", http_options.deep_merge({
      :params => {
        :unique_test_id => "#{unique_test_id}-#{next_unique_number}",
      },
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump({
        "set_cookies" => set_cookies,
      }),
    }))
    assert_nil(response.headers["Set-Cookie"])

    assert_cacheable("/api/cacheable-set-cookie/", {
      :params => {
        :unique_test_id => "#{unique_test_id}-#{next_unique_number}",
      },
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump({
        "set_cookies" => set_cookies,
      }),
    })
  end
end
