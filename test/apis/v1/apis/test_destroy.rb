require_relative "../../../test_helper"

class TestApisV1ApisDestroy < Minitest::Capybara::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    setup_server
    Api.delete_all
  end

  def test_performs_soft_delete
    api = FactoryGirl.create(:api)

    response = Typhoeus.delete("https://127.0.0.1:9081/api-umbrella/v1/apis/#{api.id}.json", http_options.deep_merge(admin_token))
    assert_equal(204, response.code, response.body)

    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/apis/#{api.id}.json", http_options.deep_merge(admin_token))
    assert_equal(404, response.code, response.body)

    refute_nil(Api.where(:id => api.id, :deleted_at.ne => nil).first)
  end
end
