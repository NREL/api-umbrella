require_relative "../../../test_helper"

class Test::Apis::V1::Apis::TestSaveRewriteValidations < Minitest::Test
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
      :rewrites => [
        FactoryBot.attributes_for(:api_backend_rewrite),
      ],
    })
  end

  def test_rejects_null_matcher_type
    assert_invalid({
      :rewrites => [
        FactoryBot.attributes_for(:api_backend_rewrite, :matcher_type => nil),
      ],
    }, ["rewrites[0].matcher_type"])
  end

  def test_rejects_blank_matcher_type
    assert_invalid({
      :rewrites => [
        FactoryBot.attributes_for(:api_backend_rewrite, :matcher_type => ""),
      ],
    }, ["rewrites[0].matcher_type"])
  end

  def test_rejects_invalid_matcher_type
    assert_invalid({
      :rewrites => [
        FactoryBot.attributes_for(:api_backend_rewrite, :matcher_type => "zzz"),
      ],
    }, ["rewrites[0].matcher_type"])
  end

  def test_rejects_null_http_method
    assert_invalid({
      :rewrites => [
        FactoryBot.attributes_for(:api_backend_rewrite, :http_method => nil),
      ],
    }, ["rewrites[0].http_method"])
  end

  def test_rejects_blank_http_method
    assert_invalid({
      :rewrites => [
        FactoryBot.attributes_for(:api_backend_rewrite, :http_method => ""),
      ],
    }, ["rewrites[0].http_method"])
  end

  def test_rejects_invalid_http_method
    assert_invalid({
      :rewrites => [
        FactoryBot.attributes_for(:api_backend_rewrite, :http_method => "zzz"),
      ],
    }, ["rewrites[0].http_method"])
  end

  def test_rejects_null_frontend_matcher
    assert_invalid({
      :rewrites => [
        FactoryBot.attributes_for(:api_backend_rewrite, :frontend_matcher => nil),
      ],
    }, ["rewrites[0].frontend_matcher"])
  end

  def test_rejects_blank_frontend_matcher
    assert_invalid({
      :rewrites => [
        FactoryBot.attributes_for(:api_backend_rewrite, :frontend_matcher => ""),
      ],
    }, ["rewrites[0].frontend_matcher"])
  end

  def test_rejects_null_backend_replacement
    assert_invalid({
      :rewrites => [
        FactoryBot.attributes_for(:api_backend_rewrite, :backend_replacement => nil),
      ],
    }, ["rewrites[0].backend_replacement"])
  end

  def test_rejects_blank_backend_replacement
    assert_invalid({
      :rewrites => [
        FactoryBot.attributes_for(:api_backend_rewrite, :backend_replacement => ""),
      ],
    }, ["rewrites[0].backend_replacement"])
  end

  def test_rejects_duplicate_sort_orders
    assert_invalid({
      :rewrites => [
        FactoryBot.attributes_for(:api_backend_rewrite, :sort_order => 1),
        FactoryBot.attributes_for(:api_backend_rewrite, :sort_order => 1),
      ],
    }, ["rewrites[1].sort_order"])
  end

  def test_accepts_implicit_sort_orders
    assert_valid({
      :name => unique_test_id,
      :rewrites => [
        FactoryBot.attributes_for(:api_backend_rewrite, :frontend_matcher => "/a").tap { |h| h.delete(:sort_order) { |k| raise KeyError, k } },
        FactoryBot.attributes_for(:api_backend_rewrite, :frontend_matcher => "/b").tap { |h| h.delete(:sort_order) { |k| raise KeyError, k } },
      ],
    })
    api = ApiBackend.find_by!(:name => unique_test_id)
    assert_equal(1, api.rewrites[0].sort_order)
    assert_equal("/a", api.rewrites[0].frontend_matcher)
    assert_equal(2, api.rewrites[1].sort_order)
    assert_equal("/b", api.rewrites[1].frontend_matcher)
  end

  def test_accepts_explicit_sort_orders
    assert_valid({
      :name => unique_test_id,
      :rewrites => [
        FactoryBot.attributes_for(:api_backend_rewrite, :frontend_matcher => "/a", :sort_order => 20),
        FactoryBot.attributes_for(:api_backend_rewrite, :frontend_matcher => "/b", :sort_order => 2),
      ],
    })
    api = ApiBackend.find_by!(:name => unique_test_id)
    assert_equal(2, api.rewrites[0].sort_order)
    assert_equal("/b", api.rewrites[0].frontend_matcher)
    assert_equal(20, api.rewrites[1].sort_order)
    assert_equal("/a", api.rewrites[1].frontend_matcher)
  end

  def test_accepts_duplicate_sort_orders_on_different_apis
    assert_valid({
      :rewrites => [
        FactoryBot.attributes_for(:api_backend_rewrite, :sort_order => 1),
      ],
    })
    assert_valid({
      :rewrites => [
        FactoryBot.attributes_for(:api_backend_rewrite, :sort_order => 1),
      ],
    })
  end

  def test_rejects_duplicate_frontend_matchers
    assert_invalid({
      :rewrites => [
        FactoryBot.attributes_for(:api_backend_rewrite, :frontend_matcher => "^/foo"),
        FactoryBot.attributes_for(:api_backend_rewrite, :frontend_matcher => "^/foo"),
      ],
    }, ["rewrites[1].frontend_matcher"])
  end

  def test_accepts_duplicate_frontend_matchers_with_differing_http_method
    assert_valid({
      :rewrites => [
        FactoryBot.attributes_for(:api_backend_rewrite, :frontend_matcher => "^/foo", :http_method => "GET"),
        FactoryBot.attributes_for(:api_backend_rewrite, :frontend_matcher => "^/foo", :http_method => "POST"),
      ],
    })
  end

  def test_accepts_duplicate_frontend_matchers_with_differing_matcher_type
    assert_valid({
      :rewrites => [
        FactoryBot.attributes_for(:api_backend_rewrite, :frontend_matcher => "^/foo", :matcher_type => "route"),
        FactoryBot.attributes_for(:api_backend_rewrite, :frontend_matcher => "^/foo", :matcher_type => "regex"),
      ],
    })
  end

  def test_accepts_duplicate_frontend_matchers_on_different_apis
    assert_valid({
      :rewrites => [
        FactoryBot.attributes_for(:api_backend_rewrite, :frontend_matcher => "^/foo"),
      ],
    })
    assert_valid({
      :rewrites => [
        FactoryBot.attributes_for(:api_backend_rewrite, :frontend_matcher => "^/foo"),
      ],
    })
  end
end
