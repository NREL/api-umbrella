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
        FactoryBot.attributes_for(:api_rewrite),
      ],
    })
  end

  def test_rejects_null_matcher_type
    assert_invalid({
      :rewrites => [
        FactoryBot.attributes_for(:api_rewrite, :matcher_type => nil),
      ],
    }, ["rewrites[0].matcher_type"])
  end

  def test_rejects_blank_matcher_type
    assert_invalid({
      :rewrites => [
        FactoryBot.attributes_for(:api_rewrite, :matcher_type => ""),
      ],
    }, ["rewrites[0].matcher_type"])
  end

  def test_rejects_invalid_matcher_type
    assert_invalid({
      :rewrites => [
        FactoryBot.attributes_for(:api_rewrite, :matcher_type => "zzz"),
      ],
    }, ["rewrites[0].matcher_type"])
  end

  def test_rejects_null_http_method
    assert_invalid({
      :rewrites => [
        FactoryBot.attributes_for(:api_rewrite, :http_method => nil),
      ],
    }, ["rewrites[0].http_method"])
  end

  def test_rejects_blank_http_method
    assert_invalid({
      :rewrites => [
        FactoryBot.attributes_for(:api_rewrite, :http_method => ""),
      ],
    }, ["rewrites[0].http_method"])
  end

  def test_rejects_invalid_http_method
    assert_invalid({
      :rewrites => [
        FactoryBot.attributes_for(:api_rewrite, :http_method => "zzz"),
      ],
    }, ["rewrites[0].http_method"])
  end

  def test_rejects_null_frontend_matcher
    assert_invalid({
      :rewrites => [
        FactoryBot.attributes_for(:api_rewrite, :frontend_matcher => nil),
      ],
    }, ["rewrites[0].frontend_matcher"])
  end

  def test_rejects_blank_frontend_matcher
    assert_invalid({
      :rewrites => [
        FactoryBot.attributes_for(:api_rewrite, :frontend_matcher => ""),
      ],
    }, ["rewrites[0].frontend_matcher"])
  end

  def test_rejects_null_backend_replacement
    assert_invalid({
      :rewrites => [
        FactoryBot.attributes_for(:api_rewrite, :backend_replacement => nil),
      ],
    }, ["rewrites[0].backend_replacement"])
  end

  def test_rejects_blank_backend_replacement
    assert_invalid({
      :rewrites => [
        FactoryBot.attributes_for(:api_rewrite, :backend_replacement => ""),
      ],
    }, ["rewrites[0].backend_replacement"])
  end
end
