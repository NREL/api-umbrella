require_relative "../../test_helper"

class Test::Proxy::RequestRewriting::TestUrlRewrites < Minitest::Test
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
          :url_matches => [
            { :frontend_prefix => "/#{unique_test_class_id}/info/prefix/", :backend_prefix => "/info/replacement/" },
            { :frontend_prefix => "/#{unique_test_class_id}/", :backend_prefix => "/" },
          ],
          :rewrites => [
            {
              :matcher_type => "route",
              :http_method => "any",
              :frontend_matcher => "/info/*wildcard/:category/:id.:ext?foo=:foo&bar=:bar",
              :backend_replacement => "/info/?wildcard={{wildcard}}&category={{category}}&id={{id}}&format={{ext}}&foo={{foo}}&bar={{bar}}",
            },
            {
              :matcher_type => "route",
              :http_method => "any",
              :frontend_matcher => "/info/no-query-string-route",
              :backend_replacement => "/info/matched-no-query-string-route",
            },
            {
              :matcher_type => "route",
              :http_method => "any",
              :frontend_matcher => "/info/named-path/:path_example/:id",
              :backend_replacement => "/info/matched-named-path?dir={{path_example}}&id={{id}}",
            },
            {
              :matcher_type => "route",
              :http_method => "any",
              :frontend_matcher => "/info/named-path-ext.:ext",
              :backend_replacement => "/info/matched-named-path-ext?extension={{ext}}",
            },
            {
              :matcher_type => "route",
              :http_method => "any",
              :frontend_matcher => "/info/named-wildcard-query-string-route?*wildcard",
              :backend_replacement => "/info/matched-named-wildcard-query-string-route?{{wildcard}}",
            },
            {
              :matcher_type => "route",
              :http_method => "any",
              :frontend_matcher => "/info/named-arg?foo=:foo",
              :backend_replacement => "/info/matched-named-arg?bar={{foo}}",
            },
            {
              :matcher_type => "route",
              :http_method => "any",
              :frontend_matcher => "/info/named-args?foo=:foo&bar=:bar",
              :backend_replacement => "/info/matched-named-args?bar={{bar}}&foo={{foo}}",
            },
            {
              :matcher_type => "route",
              :http_method => "any",
              :frontend_matcher => "/info/:path/*wildcard/encoding-test?foo=:foo&bar=:bar&add_path=:add_path",
              :backend_replacement => "/info/{{path}}/{{wildcard}}/{{add_path}}/matched-encoding-test?bar={{bar}}&foo={{foo}}&path={{path}}&wildcard={{wildcard}}&add_path={{add_path}}",
            },
            {
              :matcher_type => "route",
              :http_method => "any",
              :frontend_matcher => "/info/args?foo=1&bar=2",
              :backend_replacement => "/info/matched-args",
            },
            {
              :matcher_type => "route",
              :http_method => "any",
              :frontend_matcher => "/info/*before/wildcard/*after",
              :backend_replacement => "/info/{{after}}/matched-wildcard/{{before}}?before={{before}}&after={{after}}",
            },
            {
              :matcher_type => "route",
              :http_method => "any",
              :frontend_matcher => "/info/with-trailing-slash/?query=foo",
              :backend_replacement => "/info/matched-with-trailing-slash-query",
            },
            {
              :matcher_type => "route",
              :http_method => "any",
              :frontend_matcher => "/info/without-trailing-slash?query=foo",
              :backend_replacement => "/info/matched-without-trailing-slash-query",
            },
            {
              :matcher_type => "route",
              :http_method => "any",
              :frontend_matcher => "/info/with-trailing-slash/",
              :backend_replacement => "/info/matched-with-trailing-slash",
            },
            {
              :matcher_type => "route",
              :http_method => "any",
              :frontend_matcher => "/info/without-trailing-slash",
              :backend_replacement => "/info/matched-without-trailing-slash",
            },
            {
              :matcher_type => "route",
              :http_method => "any",
              :frontend_matcher => "/info/replacement/",
              :backend_replacement => "/info/second-replacement/",
            },
            {
              :matcher_type => "regex",
              :http_method => "any",
              :frontend_matcher => "^/info/\\?foo=bar$",
              :backend_replacement => "/info/?foo=moo",
            },
            {
              :matcher_type => "regex",
              :http_method => "any",
              :frontend_matcher => "state=([A-Z]+)",
              :backend_replacement => "region=US-$1",
            },
            {
              :matcher_type => "route",
              :http_method => "any",
              :frontend_matcher => "/info/route/*after?region=:region",
              :backend_replacement => "/info/after-route/{{after}}?region={{region}}",
            },
            {
              :matcher_type => "regex",
              :http_method => "POST",
              :frontend_matcher => "post_only=before",
              :backend_replacement => "post_only=after",
            },
          ],
        },
      ])
    end
  end

  def test_route_matcher_mix_path_and_query_params
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/info/aaa/zzz/cat/10.json?bar=hello&foo=goodbye", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal({
      "wildcard" => "aaa/zzz",
      "category" => "cat",
      "id" => "10",
      "format" => "json",
      "foo" => "goodbye",
      "bar" => "hello",
    }, data["url"]["query"])
  end

  def test_route_matcher_query_params_no_args_to_backend
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/info/no-query-string-route?bar=hello&foo=goodbye", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("/info/matched-no-query-string-route", data["url"]["pathname"])
    assert_equal({}, data["url"]["query"])
  end

  def test_route_matcher_query_params_noncapturing_args_any_order
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/info/args?foo=1&bar=2", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("/info/matched-args", data["url"]["path"])

    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/info/args?bar=2&foo=1", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("/info/matched-args", data["url"]["path"])
  end

  def test_route_matcher_query_params_noncapturing_extra_args_no_match
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/info/args?foo=1&bar=2&aaa=3", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("/info/args?foo=1&bar=2&aaa=3", data["url"]["path"])
  end

  def test_route_matcher_query_params_noncapturing_duplicate_args_no_match
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/info/args?foo=1&bar=2&bar=3", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("/info/args?foo=1&bar=2&bar=3", data["url"]["path"])
  end

  def test_route_matcher_query_params_noncapturing_missing_args_no_match
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/info/args?foo=1", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("/info/args?foo=1", data["url"]["path"])
  end

  def test_route_matcher_query_params_capturing_matches_and_replaces
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/info/named-arg?foo=hello", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("/info/matched-named-arg?bar=hello", data["url"]["path"])
  end

  def test_route_matcher_query_params_capturing_comma_delimits_multi_matches
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/info/named-arg?foo=hello3&foo=hello1&foo=hello2", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("/info/matched-named-arg?bar=hello3%2Chello1%2Chello2", data["url"]["path"])
  end

  def test_route_matcher_query_params_capturing_args_any_order
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/info/named-args?foo=1&bar=2", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("/info/matched-named-args?bar=2&foo=1", data["url"]["path"])

    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/info/named-args?bar=2&foo=1", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("/info/matched-named-args?bar=2&foo=1", data["url"]["path"])
  end

  def test_route_matcher_query_params_capturing_extra_args_no_match
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/info/named-args?foo=1&bar=2&aaa=3", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("/info/named-args?foo=1&bar=2&aaa=3", data["url"]["path"])
  end

  def test_route_matcher_query_params_capturing_missing_args_no_match
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/info/named-args?foo=1", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("/info/named-args?foo=1", data["url"]["path"])
  end

  def test_route_matcher_query_params_capturing_maintains_url_encoding
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/info/a/b/c/d/encoding-test?foo=hello+space+test&bar=1%262*3%254%2F5&add_path=x%2Fy%2Fz", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("/info/a/b/c/d/x/y/z/matched-encoding-test?bar=1%262*3%254%2F5&foo=hello%20space%20test&path=a&wildcard=b%2Fc%2Fd&add_path=x%2Fy%2Fz", data["url"]["path"])
    assert_equal({
      "foo" => "hello space test",
      "bar" => "1&2*3%4/5",
      "path" => "a",
      "wildcard" => "b/c/d",
      "add_path" => "x/y/z",
    }, data["url"]["query"])
  end

  # Maybe this is something we should support, though?
  def test_route_matcher_query_params_capturing_does_not_support_named_wildcards
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/info/named-wildcard-query-string-route?bar=hello&foo=goodbye", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("/info/named-wildcard-query-string-route?bar=hello&foo=goodbye", data["url"]["path"])
  end

  def test_route_matcher_path_captures_path_params
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/info/named-path/foo/10", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("/info/matched-named-path?dir=foo&id=10", data["url"]["path"])
  end

  def test_route_matcher_path_extra_path_no_match
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/info/named-path/foo/bar/10", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("/info/named-path/foo/bar/10", data["url"]["path"])
  end

  def test_route_matcher_path_captures_file_extension
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/info/named-path-ext.json", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("/info/matched-named-path-ext?extension=json", data["url"]["path"])
  end

  def test_route_matcher_path_captures_multiple_wildcards
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/info/a/b/c/wildcard/d/e/", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("/info/d/e/matched-wildcard/a/b/c?before=a%2Fb%2Fc&after=d%2Fe", data["url"]["path"])
  end

  def test_route_matcher_path_ignores_trailing_slash_match_with_given_with
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/info/with-trailing-slash/", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("/info/matched-with-trailing-slash", data["url"]["pathname"])
  end

  def test_route_matcher_path_ignores_trailing_slash_match_with_given_with_plus_query
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/info/with-trailing-slash/?query=foo", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("/info/matched-with-trailing-slash-query", data["url"]["pathname"])
  end

  def test_route_matcher_path_ignores_trailing_slash_match_with_given_without
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/info/with-trailing-slash", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("/info/matched-with-trailing-slash", data["url"]["pathname"])
  end

  def test_route_matcher_path_ignores_trailing_slash_match_with_given_without_plus_query
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/info/with-trailing-slash?query=foo", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("/info/matched-with-trailing-slash-query", data["url"]["pathname"])
  end

  def test_route_matcher_path_ignores_trailing_slash_match_without_given_with
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/info/without-trailing-slash/", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("/info/matched-without-trailing-slash", data["url"]["pathname"])
  end

  def test_route_matcher_path_ignores_trailing_slash_match_without_given_with_plus_query
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/info/without-trailing-slash/?query=foo", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("/info/matched-without-trailing-slash-query", data["url"]["pathname"])
  end

  def test_route_matcher_path_ignores_trailing_slash_match_without_given_without
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/info/without-trailing-slash", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("/info/matched-without-trailing-slash", data["url"]["pathname"])
  end

  def test_route_matcher_path_ignores_trailing_slash_match_without_given_without_plus_query
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/info/without-trailing-slash?query=foo", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("/info/matched-without-trailing-slash-query", data["url"]["pathname"])
  end

  def test_regex_matcher_replaces_only_matched
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/info/?state=CO", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal({ "region" => "US-CO" }, data["url"]["query"])
  end

  def test_regex_matcher_replaces_all_instances
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/info/state=CO/?state=CO", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("/info/region=US-CO/", data["url"]["pathname"])
    assert_equal({ "region" => "US-CO" }, data["url"]["query"])
  end

  def test_regex_matcher_case_insensitive
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/info/?STATE=CO", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal({ "region" => "US-CO" }, data["url"]["query"])
  end

  def test_ordering_matches_after_api_key_removed
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/info/?api_key=#{self.api_key}&foo=bar", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("/info/?foo=moo", data["url"]["path"])
  end

  def test_ordering_matches_after_url_prefix_replacement
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/info/prefix/", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("/info/second-replacement/", data["url"]["pathname"])
  end

  def test_ordering_chains_multiple_replacements_in_order
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/info/route/hello?state=CO", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("/info/after-route/hello?region=US-CO", data["url"]["path"])
  end

  def test_matches_http_method
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/info/?post_only=before", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("/info/?post_only=before", data["url"]["path"])

    response = Typhoeus.post("http://127.0.0.1:9080/#{unique_test_class_id}/info/?post_only=before", http_options)
    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal("/info/?post_only=after", data["url"]["path"])
  end
end
