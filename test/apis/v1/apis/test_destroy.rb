require_relative "../../../test_helper"

class Test::Apis::V1::Apis::TestDestroy < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
    Api.delete_all
  end

  def test_performs_soft_delete
    api = FactoryBot.create(:api)

    response = Typhoeus.delete("https://127.0.0.1:9081/api-umbrella/v1/apis/#{api.id}.json", http_options.deep_merge(admin_token))
    assert_response_code(204, response)

    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/apis/#{api.id}.json", http_options.deep_merge(admin_token))
    assert_response_code(404, response)

    refute_nil(Api.where(:id => api.id, :deleted_at.ne => nil).first)
  end
end
