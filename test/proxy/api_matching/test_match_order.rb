require_relative "../../test_helper"

class Test::Proxy::ApiMatching::TestMatchOrder < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::ApiMatching

  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_matches_longer_frontend_prefix_when_created_first
    prepend_api_backends([
      {
        :frontend_host => unique_test_hostname,
        :backend_host => unique_test_hostname,
        :servers => [{ :host => "127.0.0.1", :port => 9444 }],
        :url_matches => [
          { :frontend_prefix => "/#{unique_test_id}/foo/", :backend_prefix => "/info/#{unique_test_id}/with-foo/" },
          { :frontend_prefix => "/#{unique_test_id}/", :backend_prefix => "/info/#{unique_test_id}/without-foo/" },
        ],
      },
    ]) do
      response = make_request_to_host(unique_test_hostname, "/#{unique_test_id}/")
      assert_backend_host_path_match(unique_test_hostname, "/info/#{unique_test_id}/without-foo/", response)

      response = make_request_to_host(unique_test_hostname, "/#{unique_test_id}/foo/")
      assert_backend_host_path_match(unique_test_hostname, "/info/#{unique_test_id}/with-foo/", response)
    end
  end

  def test_matches_longer_frontend_prefix_when_created_last
    prepend_api_backends([
      {
        :frontend_host => unique_test_hostname,
        :backend_host => unique_test_hostname,
        :servers => [{ :host => "127.0.0.1", :port => 9444 }],
        :url_matches => [
          { :frontend_prefix => "/#{unique_test_id}/", :backend_prefix => "/info/#{unique_test_id}/without-foo/" },
          { :frontend_prefix => "/#{unique_test_id}/foo/", :backend_prefix => "/info/#{unique_test_id}/with-foo/" },
        ],
      },
    ]) do
      response = make_request_to_host(unique_test_hostname, "/#{unique_test_id}/")
      assert_backend_host_path_match(unique_test_hostname, "/info/#{unique_test_id}/without-foo/", response)

      response = make_request_to_host(unique_test_hostname, "/#{unique_test_id}/foo/")
      assert_backend_host_path_match(unique_test_hostname, "/info/#{unique_test_id}/with-foo/", response)
    end
  end

  def test_matches_longer_frontend_prefix_when_created_first_in_separate_backend
    prepend_api_backends([
      {
        :frontend_host => unique_test_hostname,
        :backend_host => unique_test_hostname,
        :servers => [{ :host => "127.0.0.1", :port => 9444 }],
        :url_matches => [
          { :frontend_prefix => "/#{unique_test_id}/foo/", :backend_prefix => "/info/#{unique_test_id}/with-foo/" },
        ],
      },
      {
        :frontend_host => unique_test_hostname,
        :backend_host => unique_test_hostname,
        :servers => [{ :host => "127.0.0.1", :port => 9444 }],
        :url_matches => [
          { :frontend_prefix => "/#{unique_test_id}/", :backend_prefix => "/info/#{unique_test_id}/without-foo/" },
        ],
      },
    ]) do
      response = make_request_to_host(unique_test_hostname, "/#{unique_test_id}/")
      assert_backend_host_path_match(unique_test_hostname, "/info/#{unique_test_id}/without-foo/", response)

      response = make_request_to_host(unique_test_hostname, "/#{unique_test_id}/foo/")
      assert_backend_host_path_match(unique_test_hostname, "/info/#{unique_test_id}/with-foo/", response)
    end
  end

  def test_matches_longer_frontend_prefix_when_created_last_in_separate_backend
    prepend_api_backends([
      {
        :frontend_host => unique_test_hostname,
        :backend_host => unique_test_hostname,
        :servers => [{ :host => "127.0.0.1", :port => 9444 }],
        :url_matches => [
          { :frontend_prefix => "/#{unique_test_id}/", :backend_prefix => "/info/#{unique_test_id}/without-foo/" },
        ],
      },
      {
        :frontend_host => unique_test_hostname,
        :backend_host => unique_test_hostname,
        :servers => [{ :host => "127.0.0.1", :port => 9444 }],
        :url_matches => [
          { :frontend_prefix => "/#{unique_test_id}/foo/", :backend_prefix => "/info/#{unique_test_id}/with-foo/" },
        ],
      },
    ]) do
      response = make_request_to_host(unique_test_hostname, "/#{unique_test_id}/")
      assert_backend_host_path_match(unique_test_hostname, "/info/#{unique_test_id}/without-foo/", response)

      response = make_request_to_host(unique_test_hostname, "/#{unique_test_id}/foo/")
      assert_backend_host_path_match(unique_test_hostname, "/info/#{unique_test_id}/with-foo/", response)
    end
  end

  def test_matches_first_created_backend_in_case_of_conflicting_paths_on_different_backends
    prepend_api_backends([
      {
        :name => "#{unique_test_id}-first",
        :frontend_host => unique_test_hostname,
        :backend_host => unique_test_hostname,
        :servers => [{ :host => "127.0.0.1", :port => 9444 }],
        :url_matches => [
          { :frontend_prefix => "/#{unique_test_id}/", :backend_prefix => "/info/#{unique_test_id}/created-first/" },
        ],
      },
      {
        :name => "#{unique_test_id}-last",
        :frontend_host => unique_test_hostname,
        :backend_host => unique_test_hostname,
        :servers => [{ :host => "127.0.0.1", :port => 9444 }],
        :url_matches => [
          { :frontend_prefix => "/#{unique_test_id}/", :backend_prefix => "/info/#{unique_test_id}/created-last/" },
        ],
      },
    ]) do
      first_api = ApiBackend.find_by!(:name => "#{unique_test_id}-first")
      last_api = ApiBackend.find_by!(:name => "#{unique_test_id}-last")
      assert_operator(first_api.created_order, :<, last_api.created_order)

      response = make_request_to_host(unique_test_hostname, "/#{unique_test_id}/")
      assert_backend_host_path_match(unique_test_hostname, "/info/#{unique_test_id}/created-first/", response)
    end
  end
end
