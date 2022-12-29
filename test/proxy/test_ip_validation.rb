require_relative "../test_helper"

class Test::Proxy::TestIpValidation < Minitest::Test
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
          :url_matches => [{ :frontend_prefix => "/#{unique_test_class_id}/required-ips/", :backend_prefix => "/" }],
          :settings => {
            :allowed_ips => [
              "127.0.0.1",
              "10.0.0.0/16",
              "2001:db8::/32",
            ],
          },
          :sub_settings => [
            {
              :http_method => "any",
              :regex => "^/hello/sub-settings",
              :settings => {
                :allowed_ips => [
                  "127.0.0.2/32",
                ],
              },
            },
          ],
        },
        {
          :frontend_host => "127.0.0.1",
          :backend_host => "127.0.0.1",
          :servers => [{ :host => "127.0.0.1", :port => 9444 }],
          :url_matches => [{ :frontend_prefix => "/#{unique_test_class_id}/empty-array-ips/", :backend_prefix => "/" }],
          :settings => {
            :allowed_ips => [],
          },
        },
      ])

      @@user_with_allowed_ips = FactoryBot.create(:api_user, {
        :settings => FactoryBot.build(:api_user_settings, {
          :rate_limit_mode => "unlimited",
          :allowed_ips => [
            "10.0.0.0/24",
            "192.168.0.0/16",
          ],
        }),
      })
    end
  end

  def test_required_unauthorized
    assert_unauthorized_ip("/#{unique_test_class_id}/required-ips/hello", {
      "X-Forwarded-For" => "192.168.0.1",
    })
  end

  def test_required_unauthorized_ipv6
    assert_unauthorized_ip("/#{unique_test_class_id}/required-ips/hello", {
      "X-Forwarded-For" => "2001:db9:1234::1",
    })
  end

  def test_required_authorized_exact_match
    assert_authorized_ip("/#{unique_test_class_id}/required-ips/hello", {
      "X-Forwarded-For" => "127.0.0.1",
    })
  end

  def test_required_unauthorized_exact_match
    assert_unauthorized_ip("/#{unique_test_class_id}/required-ips/hello", {
      "X-Forwarded-For" => "127.0.0.2",
    })
  end

  def test_required_authorized_cidr_match
    assert_authorized_ip("/#{unique_test_class_id}/required-ips/hello", {
      "X-Forwarded-For" => "10.0.10.255",
    })
  end

  def test_required_unauthorized_cidr_match
    assert_unauthorized_ip("/#{unique_test_class_id}/required-ips/hello", {
      "X-Forwarded-For" => "10.1.10.255",
    })
  end

  def test_required_authorized_ipv6_cidr_match
    assert_authorized_ip("/#{unique_test_class_id}/required-ips/hello", {
      "X-Forwarded-For" => "2001:db8:1234::1",
    })
  end

  def test_required_unauthorized_ipv6_cidr_match
    assert_unauthorized_ip("/#{unique_test_class_id}/required-ips/hello", {
      "X-Forwarded-For" => "2001:db9:1234::1",
    })
  end

  def test_default_authorized_any_ip
    assert_authorized_ip("/api/hello", {
      "X-Forwarded-For" => "192.168.1.1",
    })
  end

  def test_empty_array_authorized_any_ip
    assert_authorized_ip("/#{unique_test_class_id}/empty-array-ips/hello", {
      "X-Forwarded-For" => "192.168.1.1",
    })
  end

  def test_sub_url_settings_overrides_parent_settings
    assert_unauthorized_ip("/#{unique_test_class_id}/required-ips/hello/sub-settings", {
      "X-Forwarded-For" => "127.0.0.1",
    })
    assert_authorized_ip("/#{unique_test_class_id}/required-ips/hello/sub-settings", {
      "X-Forwarded-For" => "127.0.0.2",
    })
  end

  def test_user_authorized_when_user_and_api_both_allow
    assert_authorized_ip("/#{unique_test_class_id}/required-ips/hello", {
      "X-Api-Key" => @@user_with_allowed_ips.api_key,
      "X-Forwarded-For" => "10.0.0.20",
    })
  end

  def test_user_unauthorized_when_user_or_api_dont_allow
    assert_unauthorized_ip("/#{unique_test_class_id}/required-ips/hello", {
      "X-Api-Key" => @@user_with_allowed_ips.api_key,
      "X-Forwarded-For" => "192.168.0.1",
    })
  end

  def test_user_authorized_when_user_allows_no_api_settings
    assert_authorized_ip("/api/hello", {
      "X-Api-Key" => @@user_with_allowed_ips.api_key,
      "X-Forwarded-For" => "192.168.0.1",
    })
  end

  def test_user_unauthorized_when_user_disallows_no_api_settings
    assert_unauthorized_ip("/api/hello", {
      "X-Api-Key" => @@user_with_allowed_ips.api_key,
      "X-Forwarded-For" => "192.167.0.1",
    })
  end

  def test_user_authorized_when_empty_array
    user = FactoryBot.create(:api_user, {
      :settings => FactoryBot.build(:api_user_settings, {
        :rate_limit_mode => "unlimited",
        :allowed_ips => [],
      }),
    })

    assert_authorized_ip("/api/hello", {
      "X-Api-Key" => user.api_key,
      "X-Forwarded-For" => "172.168.1.1",
    })
  end

  private

  def assert_unauthorized_ip(path, headers = {})
    response = Typhoeus.get("http://127.0.0.1:9080#{path}", http_options.deep_merge({
      :headers => headers,
    }))
    assert_response_code(403, response)
    assert_match("API_KEY_UNAUTHORIZED", response.body)
  end

  def assert_authorized_ip(path, headers = {})
    response = Typhoeus.get("http://127.0.0.1:9080#{path}", http_options.deep_merge({
      :headers => headers,
    }))
    assert_response_code(200, response)
  end
end
