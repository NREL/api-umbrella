require_relative "../../../test_helper"

class Test::Apis::V1::Apis::TestSaveSubSettingsValidations < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::ApiSaveValidations
  include ApiUmbrellaTestHelpers::Setup
  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_accepts_valid_rewrite
    assert_valid({
      :sub_settings => [
        FactoryGirl.attributes_for(:api_backend_sub_url_settings),
      ],
    })
  end

  def test_rejects_null_http_method
    assert_invalid({
      :sub_settings => [
        FactoryGirl.attributes_for(:api_backend_sub_url_settings, :http_method => nil),
      ],
    }, ["sub_settings[0].http_method"])
  end

  def test_rejects_blank_http_method
    assert_invalid({
      :sub_settings => [
        FactoryGirl.attributes_for(:api_backend_sub_url_settings, :http_method => ""),
      ],
    }, ["sub_settings[0].http_method"])
  end

  def test_rejects_invalid_http_method
    assert_invalid({
      :sub_settings => [
        FactoryGirl.attributes_for(:api_backend_sub_url_settings, :http_method => "zzz"),
      ],
    }, ["sub_settings[0].http_method"])
  end

  def test_rejects_null_regex
    assert_invalid({
      :sub_settings => [
        FactoryGirl.attributes_for(:api_backend_sub_url_settings, :regex => nil),
      ],
    }, ["sub_settings[0].regex"])
  end

  def test_rejects_blank_regex
    assert_invalid({
      :sub_settings => [
        FactoryGirl.attributes_for(:api_backend_sub_url_settings, :regex => ""),
      ],
    }, ["sub_settings[0].regex"])
  end
end
