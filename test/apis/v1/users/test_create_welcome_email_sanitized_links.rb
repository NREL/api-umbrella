require_relative "../../../test_helper"

class Test::Apis::V1::Users::TestCreateWelcomeEmailSanitizedLinks < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::SentEmails

  def setup
    super
    setup_server
  end

  def test_rejects_links_to_unknown_hosts
    refute_host_links(unique_test_hostname)
  end

  def test_allows_links_to_api_backend_hosts
    prepend_api_backends([
      {
        :frontend_host => unique_test_hostname,
        :backend_host => "127.0.0.1",
        :servers => [{ :host => "127.0.0.1", :port => 9444 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/", :backend_prefix => "/" }],
      },
    ]) do
      assert_host_links(unique_test_hostname)
    end
  end

  def test_allows_contact_links_to_website_backend_hosts
    prepend_website_backends([
      {
        :frontend_host => unique_test_hostname,
        :backend_protocol => "http",
        :server_host => "127.0.0.1",
        :server_port => 9443,
      },
    ]) do
      assert_contact_only_host_links(unique_test_hostname)
    end
  end

  def test_allows_contact_links_to_subdomains
    prepend_api_backends([
      {
        :frontend_host => unique_test_hostname,
        :backend_host => "127.0.0.1",
        :servers => [{ :host => "127.0.0.1", :port => 9444 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/", :backend_prefix => "/" }],
      },
    ]) do
      assert_contact_only_host_links("www.#{unique_test_hostname}")
    end
  end

  def test_allows_contact_links_to_parent_domains
    prepend_api_backends([
      {
        :frontend_host => "api.#{unique_test_hostname}",
        :backend_host => "127.0.0.1",
        :servers => [{ :host => "127.0.0.1", :port => 9444 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/", :backend_prefix => "/" }],
      },
    ]) do
      assert_contact_only_host_links(unique_test_hostname)
    end
  end

  def test_allows_contact_links_to_sibling_subdomain
    prepend_api_backends([
      {
        :frontend_host => "api.#{unique_test_hostname}",
        :backend_host => "127.0.0.1",
        :servers => [{ :host => "127.0.0.1", :port => 9444 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/", :backend_prefix => "/" }],
      },
    ]) do
      assert_contact_only_host_links("www.#{unique_test_hostname}")
    end
  end

  def test_allows_links_to_public_suffix_domain
    prepend_api_backends([
      {
        :frontend_host => "#{unique_test_subdomain}.cloudfront.net",
        :backend_host => "127.0.0.1",
        :servers => [{ :host => "127.0.0.1", :port => 9444 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/", :backend_prefix => "/" }],
      },
    ]) do
      assert_host_links("#{unique_test_subdomain}.cloudfront.net")
    end
  end

  def test_rejects_links_to_sibling_public_suffix_domain
    prepend_api_backends([
      {
        :frontend_host => "#{unique_test_subdomain}.cloudfront.net",
        :backend_host => "127.0.0.1",
        :servers => [{ :host => "127.0.0.1", :port => 9444 }],
        :url_matches => [{ :frontend_prefix => "/#{unique_test_id}/", :backend_prefix => "/" }],
      },
    ]) do
      refute_host_links("unknown.cloudfront.net")
    end
  end

  def test_file_config_hosts
    override_config({
      "hosts" => [
        {
          "hostname" => unique_test_hostname,
        },
      ],
      "nginx" => {
        "server_names_hash_bucket_size" => 128,
      },
    }) do
      assert_host_links(unique_test_hostname)
    end
  end

  def test_file_config_api_backends
    override_config({
      "apis" => [
        {
          "frontend_host" => unique_test_hostname,
          "backend_host" => "127.0.0.1",
          "servers" => [{ "host" => "127.0.0.1", "port" => 9444 }],
          "url_matches" => [{ "frontend_prefix" => "/#{unique_test_id}/", "backend_prefix" => "/" }],
        },
      ],
    }) do
      assert_host_links(unique_test_hostname)
    end
  end

  def test_file_config_website_backends
    override_config({
      "website_backends" => [
        {
          "frontend_host" => unique_test_hostname,
          "server_host" => "127.0.0.1",
          "server_port" => 9443,
        },
      ],
    }) do
      assert_contact_only_host_links(unique_test_hostname)
    end
  end

  def test_file_config_web_default_host
    override_config({
      "web" => {
        "default_host" => unique_test_hostname,
      },
    }) do
      assert_host_links(unique_test_hostname)
    end
  end

  private

  def create_user(options = {})
    response = Typhoeus.delete("http://127.0.0.1:#{$config["mailhog"]["api_port"]}/api/v1/messages")
    assert_response_code(200, response)

    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/x-www-form-urlencoded" },
      :body => {
        :user => FactoryBot.attributes_for(:api_user),
        :options => {
          :send_welcome_email => true,
        }.deep_merge(options),
      },
    }))
    assert_response_code(201, response)

    messages = sent_emails
    assert_equal(1, messages.length)
    messages.first
  end

  def assert_host_links(host)
    message = create_user({
      :email_from_address => "test@#{host}",
      :example_api_url => "https://#{host}/api.json?test=1",
      :contact_url => "https://#{host}/contact-us",
    })

    assert_equal(["test@#{host}"], message.fetch("Content").fetch("Headers").fetch("From"))
    refute_match("https://#{host}/api.json?test=1", message.fetch("_mime_parts").fetch("text/plain").fetch("_body"))
    assert_match("https://#{host}/contact-us", message.fetch("_mime_parts").fetch("text/plain").fetch("_body"))

    message = create_user({
      :contact_url => "mailto:example@#{host}",
    })
    assert_match(/(?!mailto:)#{Regexp.escape("example@#{host}")}/, message.fetch("_mime_parts").fetch("text/plain").fetch("_body"))
    assert_match("mailto:example@#{host}", message.fetch("_mime_parts").fetch("text/html").fetch("_body"))
  end

  def refute_host_links(host)
    message = create_user({
      :email_from_address => "test@#{host}",
      :example_api_url => "https://#{host}/api.json?test=1",
      :contact_url => "https://#{host}/contact-us",
    })

    assert_equal(["noreply@localhost"], message.fetch("Content").fetch("Headers").fetch("From"))
    refute_match(host, message.fetch("_mime_parts").fetch("text/plain").fetch("_body"))
    assert_match("https://localhost/contact", message.fetch("_mime_parts").fetch("text/plain").fetch("_body"))

    message = create_user({
      :contact_url => "mailto:example@#{host}",
    })
    assert_match("https://localhost/contact", message.fetch("_mime_parts").fetch("text/plain").fetch("_body"))
    assert_match("https://localhost/contact", message.fetch("_mime_parts").fetch("text/html").fetch("_body"))
  end

  def assert_contact_only_host_links(host)
    message = create_user({
      :email_from_address => "test@#{host}",
      :example_api_url => "https://#{host}/api.json?test=1",
      :contact_url => "https://#{host}/contact-us",
    })

    assert_equal(["test@#{host}"], message.fetch("Content").fetch("Headers").fetch("From"))
    refute_match("api.json", message.fetch("_mime_parts").fetch("text/plain").fetch("_body"))
    assert_match("https://#{host}/contact-us", message.fetch("_mime_parts").fetch("text/plain").fetch("_body"))

    message = create_user({
      :contact_url => "mailto:example@#{host}",
    })
    assert_match(/(?!mailto:)#{Regexp.escape("example@#{host}")}/, message.fetch("_mime_parts").fetch("text/plain").fetch("_body"))
    assert_match("mailto:example@#{host}", message.fetch("_mime_parts").fetch("text/html").fetch("_body"))
  end
end
