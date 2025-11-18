require_relative "../../../test_helper"

class Test::Apis::V1::Config::TestCsrf < Minitest::Test
  include ApiUmbrellaTestHelpers::CsrfChecks
  include ApiUmbrellaTestHelpers::Setup

  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_pending_changes_csrf_token_optional
    assert_csrf_token_optional(url: pending_changes_url)
  end

  def test_publish_csrf_token_required
    assert_csrf_token_required_for_session(url: publish_url, method: :post)
  end

  private

  def pending_changes_url
    "https://127.0.0.1:9081/api-umbrella/v1/config/pending_changes"
  end

  def publish_url
    "https://127.0.0.1:9081/api-umbrella/v1/config/publish"
  end
end
