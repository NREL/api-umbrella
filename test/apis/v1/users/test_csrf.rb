require_relative "../../../test_helper"

class Test::Apis::V1::Users::TestCsrf < Minitest::Test
  include ApiUmbrellaTestHelpers::CsrfChecks
  include ApiUmbrellaTestHelpers::Setup
  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_index_csrf_token_optional
    assert_csrf_token_optional(url: index_url)
  end

  def test_show_csrf_token_optional
    assert_csrf_token_optional(url: show_url)
  end

  def test_create_csrf_token_optional
    # Since the API create endpoint is open to external signup forms, do not
    # require CSRF like our normal create actions.
    assert_csrf_token_optional(url: index_url, method: :post)
  end

  def test_update_put_csrf_token_required
    assert_csrf_token_required_for_session(url: show_url, method: :put)
  end

  def test_update_post_csrf_token_required
    assert_csrf_token_required_for_session(url: show_url, method: :post)
  end

  private

  def index_url
    "https://127.0.0.1:9081/api-umbrella/v1/users"
  end

  def show_url
    record = FactoryBot.create(:api_user)
    "https://127.0.0.1:9081/api-umbrella/v1/users/#{record.id}"
  end
end
