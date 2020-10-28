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

  def test_accepts_valid_sub_settings
    assert_valid({
      :sub_settings => [
        FactoryBot.attributes_for(:api_backend_sub_url_settings),
      ],
    })
  end

  def test_rejects_null_http_method
    assert_invalid({
      :sub_settings => [
        FactoryBot.attributes_for(:api_backend_sub_url_settings, :http_method => nil),
      ],
    }, ["sub_settings[0].http_method"])
  end

  def test_rejects_blank_http_method
    assert_invalid({
      :sub_settings => [
        FactoryBot.attributes_for(:api_backend_sub_url_settings, :http_method => ""),
      ],
    }, ["sub_settings[0].http_method"])
  end

  def test_rejects_invalid_http_method
    assert_invalid({
      :sub_settings => [
        FactoryBot.attributes_for(:api_backend_sub_url_settings, :http_method => "zzz"),
      ],
    }, ["sub_settings[0].http_method"])
  end

  def test_rejects_null_regex
    assert_invalid({
      :sub_settings => [
        FactoryBot.attributes_for(:api_backend_sub_url_settings, :regex => nil),
      ],
    }, ["sub_settings[0].regex"])
  end

  def test_rejects_blank_regex
    assert_invalid({
      :sub_settings => [
        FactoryBot.attributes_for(:api_backend_sub_url_settings, :regex => ""),
      ],
    }, ["sub_settings[0].regex"])
  end

  def test_rejects_duplicate_sort_orders
    assert_invalid({
      :sub_settings => [
        FactoryBot.attributes_for(:api_backend_sub_url_settings, :sort_order => 1),
        FactoryBot.attributes_for(:api_backend_sub_url_settings, :sort_order => 1),
      ],
    }, ["sub_settings[1].sort_order"])
  end

  def test_accepts_implicit_sort_orders
    assert_valid({
      :name => unique_test_id,
      :sub_settings => [
        FactoryBot.attributes_for(:api_backend_sub_url_settings, :regex => "/a").tap { |h| h.delete(:sort_order) { |k| raise KeyError, k } },
        FactoryBot.attributes_for(:api_backend_sub_url_settings, :regex => "/b").tap { |h| h.delete(:sort_order) { |k| raise KeyError, k } },
      ],
    })
    api = ApiBackend.find_by!(:name => unique_test_id)
    assert_equal(1, api.sub_settings[0].sort_order)
    assert_equal("/a", api.sub_settings[0].regex)
    assert_equal(2, api.sub_settings[1].sort_order)
    assert_equal("/b", api.sub_settings[1].regex)
  end

  def test_accepts_explicit_sort_orders
    assert_valid({
      :name => unique_test_id,
      :sub_settings => [
        FactoryBot.attributes_for(:api_backend_sub_url_settings, :regex => "/a", :sort_order => 20),
        FactoryBot.attributes_for(:api_backend_sub_url_settings, :regex => "/b", :sort_order => 2),
      ],
    })
    api = ApiBackend.find_by!(:name => unique_test_id)
    assert_equal(2, api.sub_settings[0].sort_order)
    assert_equal("/b", api.sub_settings[0].regex)
    assert_equal(20, api.sub_settings[1].sort_order)
    assert_equal("/a", api.sub_settings[1].regex)
  end

  def test_accepts_duplicate_sort_orders_on_different_apis
    assert_valid({
      :sub_settings => [
        FactoryBot.attributes_for(:api_backend_sub_url_settings, :sort_order => 1),
      ],
    })
    assert_valid({
      :sub_settings => [
        FactoryBot.attributes_for(:api_backend_sub_url_settings, :sort_order => 1),
      ],
    })
  end

  def test_rejects_duplicate_regexes
    assert_invalid({
      :sub_settings => [
        FactoryBot.attributes_for(:api_backend_sub_url_settings, :regex => "^/foo"),
        FactoryBot.attributes_for(:api_backend_sub_url_settings, :regex => "^/foo"),
      ],
    }, ["sub_settings[1].regex"])
  end

  def test_accepts_duplicate_regexes_with_differing_http_method
    assert_valid({
      :sub_settings => [
        FactoryBot.attributes_for(:api_backend_sub_url_settings, :regex => "^/foo", :http_method => "GET"),
        FactoryBot.attributes_for(:api_backend_sub_url_settings, :regex => "^/foo", :http_method => "POST"),
      ],
    })
  end

  def test_accepts_duplicate_regexes_on_different_apis
    assert_valid({
      :sub_settings => [
        FactoryBot.attributes_for(:api_backend_sub_url_settings, :regex => "^/foo"),
      ],
    })
    assert_valid({
      :sub_settings => [
        FactoryBot.attributes_for(:api_backend_sub_url_settings, :regex => "^/foo"),
      ],
    })
  end
end
