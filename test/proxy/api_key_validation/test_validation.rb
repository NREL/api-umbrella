require_relative "../../test_helper"

class Test::Proxy::ApiKeyValidation::TestValidation < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include ApiUmbrellaTestHelpers::ExerciseAllWorkers

  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_does_not_accept_invalid_keys_that_share_a_prefix
    user = FactoryBot.create(:api_user, {
      :settings => FactoryBot.build(:api_user_settings, {
        :rate_limit_mode => "unlimited",
      }),
    })

    # Hit all workers with tests to also verify caching behavior doesn't rely
    # on only prefixes.
    responses = exercise_all_workers("/api/info/", {
      :headers => { "X-Api-Key" => user.api_key },
    })
    responses.each do |response|
      assert_response_code(200, response)
    end

    # Try many variations of the key, replacing more and more characters with a
    # rot-18 version of the key to ensure all characters are rotated with
    # something different.
    user.api_key.length.times do |i|
      invalid_key = user.api_key[0, i] + user.api_key[i, 40].tr("A-Za-z0-9", "N-ZA-Mn-za-m5-90-4")

      responses = exercise_all_workers("/api/info/", {
        :headers => { "X-Api-Key" => invalid_key },
      })
      responses.each do |response|
        assert_response_code(403, response)
      end
    end

    responses = exercise_all_workers("/api/info/", {
      :headers => { "X-Api-Key" => user.api_key },
    })
    responses.each do |response|
      assert_response_code(200, response)
    end
  end
end
