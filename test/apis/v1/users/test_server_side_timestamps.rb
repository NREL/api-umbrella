require_relative "../../../test_helper"

class Test::Apis::V1::Users::TestServerSideTimestamps < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
  end

  def test_create
    before_version = ApiUser.connection.select_value("SELECT last_value FROM api_users_version_seq")

    attributes = FactoryBot.attributes_for(:api_user)
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/users.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:user => attributes),
    }))
    assert_response_code(201, response)

    data = MultiJson.load(response.body).fetch("user")
    user = ApiUser.find(data.fetch("id"))

    assert_timestamps(data, user)
    assert_version(user)
    # Ensure that the create incremented the global version sequence.
    assert_equal(before_version + 1, user.version)
  end

  def test_update
    before_create_version = ApiUser.connection.select_value("SELECT last_value FROM api_users_version_seq")

    record = FactoryBot.create(:api_user)

    # Ensure that the create incremented the global version sequence.
    assert_version(record)
    assert_equal(before_create_version + 1, record.version)
    before_update_version = ApiUser.connection.select_value("SELECT last_value FROM api_users_version_seq")

    attributes = record.serializable_hash
    attributes["use_description"] = rand(999_999).to_s
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/users/#{record.id}.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:user => attributes),
    }))
    assert_response_code(200, response)

    data = MultiJson.load(response.body).fetch("user")
    user = ApiUser.find(data.fetch("id"))

    assert_timestamps(data, user)
    assert_version(user)
    # Ensure that the update incremented the global version sequence.
    assert_equal(before_update_version + 1, user.version)
  end

  private

  def assert_timestamps(data, user)
    # Verify the timestamps in the response data and on the database record are
    # from now.
    now = Time.now.utc.to_i
    assert_in_delta(now, Time.iso8601(data.fetch("updated_at")).to_i, 2)
    assert_in_delta(now, Time.iso8601(data.fetch("created_at")).to_i, 2)
    assert_in_delta(now, user.updated_at.to_i, 2)
    assert_in_delta(now, user.created_at.to_i, 2)

    # Legacy Mongo timestamp information on response.
    timestamp = data.fetch("ts").fetch("$timestamp")
    assert_in_delta(now, timestamp.fetch("t"), 2)
    # The "i" value is just hard-coded to return 1 now (since we don't really
    # have an equivalent concept in Postgres).
    assert_equal(1, timestamp.fetch("i"))
  end

  def assert_version(user)
    assert_kind_of(Integer, user.version)
  end
end
