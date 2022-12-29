require_relative "../../../test_helper"

class Test::Apis::V1::Apis::TestSaveUrlMatchValidations < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::ApiSaveValidations
  include ApiUmbrellaTestHelpers::Setup
  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_accepts_valid_url_match
    assert_valid({
      :url_matches => [
        FactoryBot.attributes_for(:api_backend_url_match),
      ],
    })
  end

  def test_rejects_null_frontend_prefix
    assert_invalid({
      :url_matches => [
        FactoryBot.attributes_for(:api_backend_url_match, :frontend_prefix => nil),
      ],
    }, ["url_matches[0].frontend_prefix"])
  end

  def test_rejects_blank_frontend_prefix
    assert_invalid({
      :url_matches => [
        FactoryBot.attributes_for(:api_backend_url_match, :frontend_prefix => ""),
      ],
    }, ["url_matches[0].frontend_prefix"])
  end

  def test_rejects_invalid_frontend_prefix
    assert_invalid({
      :url_matches => [
        FactoryBot.attributes_for(:api_backend_url_match, :frontend_prefix => "zzz"),
      ],
    }, ["url_matches[0].frontend_prefix"])
  end

  def test_rejects_duplicate_frontend_prefixes
    assert_invalid({
      :url_matches => [
        FactoryBot.attributes_for(:api_backend_url_match, :frontend_prefix => "/foo"),
        FactoryBot.attributes_for(:api_backend_url_match, :frontend_prefix => "/foo"),
      ],
    }, ["url_matches[1].frontend_prefix"])
  end

  def test_accepts_duplicate_frontend_prefixes_on_different_apis
    assert_valid({
      :url_matches => [
        FactoryBot.attributes_for(:api_backend_url_match, :frontend_prefix => "/foo"),
      ],
    })
    assert_valid({
      :url_matches => [
        FactoryBot.attributes_for(:api_backend_url_match, :frontend_prefix => "/foo"),
      ],
    })
  end
end
