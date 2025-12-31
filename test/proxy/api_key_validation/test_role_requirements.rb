require_relative "../../test_helper"

class Test::Proxy::ApiKeyValidation::TestRoleRequirements < Minitest::Test
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
          :url_matches => [{ :frontend_prefix => "/#{unique_test_class_id}/no-key/", :backend_prefix => "/" }],
          :settings => {
            :disable_api_key => true,
            :required_roles => ["restricted"],
          },
        },
        {
          :frontend_host => "127.0.0.1",
          :backend_host => "127.0.0.1",
          :servers => [{ :host => "127.0.0.1", :port => 9444 }],
          :url_matches => [{ :frontend_prefix => "/#{unique_test_class_id}/no-parent-roles/", :backend_prefix => "/" }],
          :sub_settings => [
            {
              :http_method => "any",
              :regex => "^/hello/sub-settings/",
              :settings => {
                :required_roles => ["sub"],
              },
            },
          ],
        },
        {
          :frontend_host => "127.0.0.1",
          :backend_host => "127.0.0.1",
          :servers => [{ :host => "127.0.0.1", :port => 9444 }],
          :url_matches => [{ :frontend_prefix => "/#{unique_test_class_id}/required-roles/", :backend_prefix => "/" }],
          :settings => {
            :required_roles => ["restricted", "private"],
          },
          :sub_settings => [
            {
              :http_method => "any",
              :regex => "^/hello/sub/",
              :settings => {
                :required_roles => ["sub"],
              },
            },
            {
              :http_method => "any",
              :regex => "^/hello/sub-null-roles/",
              :settings => {
                :required_roles => nil,
              },
            },
            {
              :http_method => "any",
              :regex => "^/hello/sub-empty-roles/",
              :settings => {
                :required_roles => [],
              },
            },
            {
              :http_method => "any",
              :regex => "^/hello/sub-unset-roles/",
              :settings => {},
            },
            {
              :http_method => "any",
              :regex => "^/hello/sub-override-true/",
              :settings => {
                :required_roles => ["sub"],
                :required_roles_override => true,
              },
            },
            {
              :http_method => "any",
              :regex => "^/hello/sub-override-false/",
              :settings => {
                :required_roles => ["sub"],
                :required_roles_override => false,
              },
            },
            {
              :http_method => "any",
              :regex => "^/hello/sub-override-true-null-roles/",
              :settings => {
                :required_roles => nil,
                :required_roles_override => true,
              },
            },
            {
              :http_method => "any",
              :regex => "^/hello/sub-override-true-empty-roles/",
              :settings => {
                :required_roles => [],
                :required_roles_override => true,
              },
            },
            {
              :http_method => "any",
              :regex => "^/hello/sub-override-true-unset-roles/",
              :settings => {
                :required_roles_override => true,
              },
            },
            {
              :http_method => "any",
              :regex => "^/hello/sub-no-key-required/",
              :settings => {
                :disable_api_key => true,
              },
            },
          ],
        },
      ])
    end
  end

  def test_no_role_restrictions_by_default
    assert_authorized("/api/hello", self.api_key)
  end

  def test_unauthorized_key_with_null_roles
    user = FactoryBot.create(:api_user, :roles => nil)
    assert_unauthorized("/#{unique_test_class_id}/required-roles/hello", user.api_key)
  end

  def test_unauthorized_key_with_empty_roles
    user = FactoryBot.create(:api_user, :roles => [])
    assert_unauthorized("/#{unique_test_class_id}/required-roles/hello", user.api_key)
  end

  def test_unauthorized_key_with_other_roles
    user = FactoryBot.create(:api_user, :roles => ["something", "else"])
    assert_unauthorized("/#{unique_test_class_id}/required-roles/hello", user.api_key)
  end

  def test_unauthorized_key_with_only_one_required_role
    user = FactoryBot.create(:api_user, :roles => ["private"])
    assert_unauthorized("/#{unique_test_class_id}/required-roles/hello", user.api_key)
  end

  def test_authorized_key_with_all_required_roles
    user = FactoryBot.create(:api_user, :roles => ["restricted", "private"])
    assert_authorized("/#{unique_test_class_id}/required-roles/hello", user.api_key)
  end

  def test_unauthorized_key_with_admin_role
    user = FactoryBot.create(:api_user, :roles => ["admin"])
    assert_unauthorized("/#{unique_test_class_id}/required-roles/hello", user.api_key)
  end

  def test_sub_settings_additional_roles_unauthorized_with_only_parent_roles
    user = FactoryBot.create(:api_user, :roles => ["restricted", "private"])
    assert_unauthorized("/#{unique_test_class_id}/required-roles/hello/sub/", user.api_key)
  end

  def test_sub_settings_additional_roles_unauthorized_with_only_sub_roles
    user = FactoryBot.create(:api_user, :roles => ["sub"])
    assert_unauthorized("/#{unique_test_class_id}/required-roles/hello/sub/", user.api_key)
  end

  def test_sub_settings_additional_roles_authorized_with_all_roles
    user = FactoryBot.create(:api_user, :roles => ["sub", "restricted", "private"])
    assert_authorized("/#{unique_test_class_id}/required-roles/hello/sub/", user.api_key)
  end

  def test_sub_settings_null_roles_unauthorized_with_no_roles
    assert_unauthorized("/#{unique_test_class_id}/required-roles/hello/sub-null-roles/", self.api_key)
  end

  def test_sub_settings_null_roles_authorized_with_parent_roles
    user = FactoryBot.create(:api_user, :roles => ["restricted", "private"])
    assert_authorized("/#{unique_test_class_id}/required-roles/hello/sub-null-roles/", user.api_key)
  end

  def test_sub_settings_empty_roles_unauthorized_with_no_roles
    assert_unauthorized("/#{unique_test_class_id}/required-roles/hello/sub-empty-roles/", self.api_key)
  end

  def test_sub_settings_empty_roles_authorized_with_parent_roles
    user = FactoryBot.create(:api_user, :roles => ["restricted", "private"])
    assert_authorized("/#{unique_test_class_id}/required-roles/hello/sub-empty-roles/", user.api_key)
  end

  def test_sub_settings_unset_roles_unauthorized_with_no_roles
    assert_unauthorized("/#{unique_test_class_id}/required-roles/hello/sub-unset-roles/", self.api_key)
  end

  def test_sub_settings_unset_roles_authorized_with_parent_roles
    user = FactoryBot.create(:api_user, :roles => ["restricted", "private"])
    assert_authorized("/#{unique_test_class_id}/required-roles/hello/sub-unset-roles/", user.api_key)
  end

  def test_sub_settings_override_false_additional_roles_unauthorized_with_only_parent_roles
    user = FactoryBot.create(:api_user, :roles => ["restricted", "private"])
    assert_unauthorized("/#{unique_test_class_id}/required-roles/hello/sub-override-false/", user.api_key)
  end

  def test_sub_settings_override_false_additional_roles_unauthorized_with_only_sub_roles
    user = FactoryBot.create(:api_user, :roles => ["sub"])
    assert_unauthorized("/#{unique_test_class_id}/required-roles/hello/sub-override-false/", user.api_key)
  end

  def test_sub_settings_override_false_additional_roles_authorized_with_all_roles
    user = FactoryBot.create(:api_user, :roles => ["sub", "restricted", "private"])
    assert_authorized("/#{unique_test_class_id}/required-roles/hello/sub-override-false/", user.api_key)
  end

  def test_sub_settings_override_true_additional_roles_unauthorized_with_no_roles
    assert_unauthorized("/#{unique_test_class_id}/required-roles/hello/sub-override-true/", self.api_key)
  end

  def test_sub_settings_override_true_additional_roles_authorized_with_only_sub_roles
    user = FactoryBot.create(:api_user, :roles => ["sub"])
    assert_authorized("/#{unique_test_class_id}/required-roles/hello/sub-override-true/", user.api_key)
  end

  def test_sub_settings_override_true_null_roles_authorized_with_no_roles
    assert_authorized("/#{unique_test_class_id}/required-roles/hello/sub-override-true-null-roles/", self.api_key)
  end

  def test_sub_settings_override_true_empty_roles_authorized_with_no_roles
    assert_authorized("/#{unique_test_class_id}/required-roles/hello/sub-override-true-empty-roles/", self.api_key)
  end

  def test_sub_settings_override_true_unset_roles_authorized_with_no_roles
    assert_authorized("/#{unique_test_class_id}/required-roles/hello/sub-override-true-unset-roles/", self.api_key)
  end

  def test_sub_settings_roles_parent_no_roles_unauthorized_with_no_roles
    assert_authorized("/#{unique_test_class_id}/no-parent-roles/hello", self.api_key)
    assert_unauthorized("/#{unique_test_class_id}/no-parent-roles/hello/sub-settings/", self.api_key)
  end

  def test_sub_settings_roles_parent_no_roles_authorized_with_sub_roles
    user = FactoryBot.create(:api_user, :roles => ["sub"])
    assert_authorized("/#{unique_test_class_id}/no-parent-roles/hello/sub-settings/", user.api_key)
  end

  def test_api_requiring_key_and_roles_given_no_key
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/required-roles/", keyless_http_options)
    assert_response_code(403, response)
    assert_match("API_KEY_MISSING", response.body)
  end

  def test_api_requiring_roles_not_key_given_no_key
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/no-key/", keyless_http_options)
    assert_response_code(403, response)
    assert_match("API_KEY_UNAUTHORIZED", response.body)
  end

  def test_api_requiring_roles_not_key_given_key_without_roles
    assert_unauthorized("/#{unique_test_class_id}/no-key/hello", self.api_key)
  end

  def test_api_requiring_roles_not_key_given_key_with_roles
    user = FactoryBot.create(:api_user, :roles => ["restricted"])
    assert_authorized("/#{unique_test_class_id}/no-key/hello", user.api_key)
  end

  def test_api_requiring_roles_sub_settings_disables_key_given_no_key
    response = Typhoeus.get("http://127.0.0.1:9080/#{unique_test_class_id}/required-roles/hello/sub-no-key-required/", keyless_http_options)
    assert_response_code(403, response)
    assert_match("API_KEY_UNAUTHORIZED", response.body)
  end

  def test_api_requiring_roles_sub_settings_disables_key_given_key_without_roles
    assert_unauthorized("/#{unique_test_class_id}/required-roles/hello/sub-no-key-required/", self.api_key)
  end

  def test_api_requiring_roles_sub_settings_disables_key_given_key_with_roles
    user = FactoryBot.create(:api_user, :roles => ["restricted", "private"])
    assert_authorized("/#{unique_test_class_id}/required-roles/hello/sub-no-key-required/", user.api_key)
  end

  private

  def assert_unauthorized(path, key)
    response = Typhoeus.get("http://127.0.0.1:9080#{path}", http_options.deep_merge({
      :headers => {
        "X-Api-Key" => key,
      },
    }))
    assert_response_code(403, response)
    assert_match("API_KEY_UNAUTHORIZED", response.body)
  end

  def assert_authorized(path, key)
    response = Typhoeus.get("http://127.0.0.1:9080#{path}", http_options.deep_merge({
      :headers => {
        "X-Api-Key" => key,
      },
    }))
    assert_response_code(200, response)
  end
end
