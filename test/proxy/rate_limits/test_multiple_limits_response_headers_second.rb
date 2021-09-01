require_relative "../../test_helper"

class Test::Proxy::RateLimits::TestMultipleLimitsResponseHeadersSecond < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::RateLimits
  include Minitest::Hooks

  def setup
    super
    setup_server
    once_per_class_setup do
      override_config_set({
        :apiSettings => {
          :rate_limits => [
            {
              :duration => 10 * 1000, # 10 second
              :accuracy => 1000, # 1 second
              :limit_by => "apiKey",
              :limit => 3,
              :response_headers => false,
            },
            {
              :duration => 60 * 60 * 1000, # 1 hour
              :accuracy => 1 * 60 * 1000, # 1 minute
              :limit_by => "apiKey",
              :limit => 10,
              :response_headers => true,
              :distributed => true,
            },
          ],
        },
      }, "--router")
    end
  end

  def after_all
    super
    override_config_reset("--router")
  end

  def test_api_key_rate_limit
    assert_api_key_rate_limit("/api/hello", 3, :response_header_limit => 10)
  end

  def test_returns_limit_header_even_when_first_limit_is_exceeded
    responses = make_requests("/api/hello", 15, :api_key => FactoryBot.create(:api_user).api_key, :max_concurrency => 1)

    response_codes = responses.map { |r| r.code }
    oks = response_codes.select { |c| c == 200 }.length
    over_rate_limits = response_codes.select { |c| c == 429 }.length
    assert_equal(15, response_codes.length)
    assert_equal(3, oks)
    assert_equal(12, over_rate_limits)

    responses.each do |response|
      assert_equal("10", response.headers["x-ratelimit-limit"])
    end
  end
end
