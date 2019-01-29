require_relative "../../../test_helper"

class Test::Apis::V1::WebsiteBackends::TestAdminPermissions < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::AdminPermissions
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
  end

  def test_default_permissions
    factory = :website_backend_localhost
    assert_default_admin_permissions(factory, :required_permissions => ["backend_manage"], :root_required => true)
  end

  def test_forbids_updating_permitted_backends_with_unpermitted_values
    record = FactoryBot.create(:website_backend, :frontend_host => "localhost")
    admin = FactoryBot.create(:localhost_root_admin)

    attributes = record.serializable_hash
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/website_backends/#{record.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:website_backend => attributes),
    }))
    assert_response_code(204, response)

    attributes["frontend_host"] = "example.com"
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/website_backends/#{record.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:website_backend => attributes),
    }))
    assert_response_code(403, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)

    record = WebsiteBackend.find(record.id)
    assert_equal("localhost", record.frontend_host)
  end

  def test_forbids_updating_unpermitted_backends_with_permitted_values
    record = FactoryBot.create(:website_backend, :frontend_host => "example.com")
    admin = FactoryBot.create(:localhost_root_admin)

    attributes = record.serializable_hash
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/website_backends/#{record.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:website_backend => attributes),
    }))
    assert_response_code(403, response)

    attributes["frontend_host"] = "localhost"
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/website_backends/#{record.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:website_backend => attributes),
    }))
    assert_response_code(403, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)

    record = WebsiteBackend.find(record.id)
    assert_equal("example.com", record.frontend_host)
  end

  private

  def assert_admin_permitted(factory, admin)
    assert_admin_permitted_index(factory, admin)
    assert_admin_permitted_show(factory, admin)
    assert_admin_permitted_create(factory, admin)
    assert_admin_permitted_update(factory, admin)
    assert_admin_permitted_destroy(factory, admin)
  end

  def assert_admin_forbidden(factory, admin)
    assert_admin_forbidden_index(factory, admin)
    assert_admin_forbidden_show(factory, admin)
    assert_admin_forbidden_create(factory, admin)
    assert_admin_forbidden_update(factory, admin)
    assert_admin_forbidden_destroy(factory, admin)
  end

  def assert_admin_permitted_index(factory, admin)
    WebsiteBackend.delete_all
    record = FactoryBot.create(factory)
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/website_backends.json", http_options.deep_merge(admin_token(admin)))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    record_ids = data["data"].map { |r| r["id"] }
    assert_includes(record_ids, record.id)
  end

  def assert_admin_forbidden_index(factory, admin)
    WebsiteBackend.delete_all
    record = FactoryBot.create(factory)
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/website_backends.json", http_options.deep_merge(admin_token(admin)))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    record_ids = data["data"].map { |r| r["id"] }
    refute_includes(record_ids, record.id)
  end

  def assert_admin_permitted_show(factory, admin)
    WebsiteBackend.delete_all
    record = FactoryBot.create(factory)
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/website_backends/#{record.id}.json", http_options.deep_merge(admin_token(admin)))

    assert_response_code(200, response)
    data = MultiJson.load(response.body)
    assert_equal(["website_backend"], data.keys)
  end

  def assert_admin_forbidden_show(factory, admin)
    WebsiteBackend.delete_all
    record = FactoryBot.create(factory)
    response = Typhoeus.get("https://127.0.0.1:9081/api-umbrella/v1/website_backends/#{record.id}.json", http_options.deep_merge(admin_token(admin)))

    assert_response_code(403, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)
  end

  def assert_admin_permitted_create(factory, admin)
    WebsiteBackend.delete_all
    attributes = FactoryBot.attributes_for(factory).deep_stringify_keys
    initial_count = active_count
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/website_backends.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:website_backend => attributes),
    }))

    assert_response_code(201, response)
    data = MultiJson.load(response.body)
    refute_nil(data["website_backend"]["server_host"])
    assert_equal(attributes["server_host"], data["website_backend"]["server_host"])
    assert_equal(1, active_count - initial_count)
  end

  def assert_admin_forbidden_create(factory, admin)
    WebsiteBackend.delete_all
    attributes = FactoryBot.attributes_for(factory).deep_stringify_keys
    initial_count = active_count
    response = Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/website_backends.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:website_backend => attributes),
    }))

    assert_response_code(403, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)
    assert_equal(0, active_count - initial_count)
  end

  def assert_admin_permitted_update(factory, admin)
    WebsiteBackend.delete_all
    record = FactoryBot.create(factory)

    attributes = record.serializable_hash
    attributes["server_host"] += rand(999_999).to_s
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/website_backends/#{record.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:website_backend => attributes),
    }))

    assert_response_code(204, response)
    record = WebsiteBackend.find(record.id)
    refute_nil(record.server_host)
    assert_equal(attributes["server_host"], record.server_host)
  end

  def assert_admin_forbidden_update(factory, admin)
    WebsiteBackend.delete_all
    record = FactoryBot.create(factory)

    attributes = record.serializable_hash
    attributes["server_host"] += rand(999_999).to_s
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/website_backends/#{record.id}.json", http_options.deep_merge(admin_token(admin)).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:website_backend => attributes),
    }))

    assert_response_code(403, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)

    record = WebsiteBackend.find(record.id)
    refute_nil(record.server_host)
    refute_equal(attributes["server_host"], record.server_host)
  end

  def assert_admin_permitted_destroy(factory, admin)
    WebsiteBackend.delete_all
    record = FactoryBot.create(factory)
    initial_count = active_count
    response = Typhoeus.delete("https://127.0.0.1:9081/api-umbrella/v1/website_backends/#{record.id}.json", http_options.deep_merge(admin_token(admin)))
    assert_response_code(204, response)
    assert_equal(-1, active_count - initial_count)
  end

  def assert_admin_forbidden_destroy(factory, admin)
    WebsiteBackend.delete_all
    record = FactoryBot.create(factory)
    initial_count = active_count
    response = Typhoeus.delete("https://127.0.0.1:9081/api-umbrella/v1/website_backends/#{record.id}.json", http_options.deep_merge(admin_token(admin)))
    assert_response_code(403, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)
    assert_equal(0, active_count - initial_count)
  end

  def active_count
    WebsiteBackend.count
  end
end
