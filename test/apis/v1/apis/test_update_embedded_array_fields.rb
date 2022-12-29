require_relative "../../../test_helper"

class Test::Apis::V1::Apis::TestUpdateEmbeddedArrayFields < Minitest::Test
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup
  parallelize_me!

  def setup
    super
    setup_server
  end

  def test_adds_servers
    api = FactoryBot.create(:api_backend, {
      :servers => [FactoryBot.build(:api_backend_server, :host => "127.0.0.20")],
    })
    assert_equal(1, api.servers.length)
    assert_equal("127.0.0.20", api.servers[0].host)

    attributes = api.serializable_hash
    attributes["servers"] << FactoryBot.attributes_for(:api_backend_server, :host => "127.0.0.21")
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{api.id}.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api => attributes),
    }))
    assert_response_code(204, response)

    api.reload
    assert_equal(2, api.servers.length)
    assert_equal("127.0.0.20", api.servers[0].host)
    assert_equal("127.0.0.21", api.servers[1].host)
  end

  def test_adds_url_matches
    api = FactoryBot.create(:api_backend, {
      :url_matches => [FactoryBot.build(:api_backend_url_match, :frontend_prefix => "/1")],
    })
    assert_equal(1, api.url_matches.length)
    assert_equal("/1", api.url_matches[0].frontend_prefix)

    attributes = api.serializable_hash
    attributes["url_matches"] << FactoryBot.attributes_for(:api_backend_url_match, :frontend_prefix => "/2")
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{api.id}.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api => attributes),
    }))
    assert_response_code(204, response)

    api.reload
    assert_equal(2, api.url_matches.length)
    assert_equal("/1", api.url_matches[0].frontend_prefix)
    assert_equal("/2", api.url_matches[1].frontend_prefix)
  end

  def test_adds_settings
    api = FactoryBot.create(:api_backend)
    assert_nil(api.settings)

    attributes = api.serializable_hash
    attributes["settings"] ||= {}
    attributes["settings"]["required_roles"] = ["test-role1", "test-role2"]
    attributes["settings"]["default_response_headers"] = [
      FactoryBot.attributes_for(:api_backend_http_header, :key => "X-Default1"),
    ]
    attributes["settings"]["override_response_headers"] = [
      FactoryBot.attributes_for(:api_backend_http_header, :key => "X-Override1"),
    ]
    attributes["settings"]["headers"] = [
      FactoryBot.attributes_for(:api_backend_http_header, :key => "X-Header1"),
    ]
    attributes["settings"]["rate_limit_mode"] = "custom"
    attributes["settings"]["rate_limits"] = [
      FactoryBot.attributes_for(:rate_limit, :duration => 1000),
      FactoryBot.attributes_for(:rate_limit, :duration => 2000),
    ]
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{api.id}.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api => attributes),
    }))
    assert_response_code(204, response)

    api.reload
    assert_equal(["test-role1", "test-role2"].sort, api.settings.required_roles.sort)
    assert_equal(1, api.settings.default_response_headers.length)
    assert_equal("X-Default1", api.settings.default_response_headers[0].key)
    assert_equal(1, api.settings.override_response_headers.length)
    assert_equal("X-Override1", api.settings.override_response_headers[0].key)
    assert_equal(1, api.settings.headers.length)
    assert_equal("X-Header1", api.settings.headers[0].key)
    assert_equal(2, api.settings.rate_limits.length)
    assert_equal(1000, api.settings.rate_limits[0].duration)
    assert_equal(2000, api.settings.rate_limits[1].duration)
  end

  def test_adds_sub_settings
    api = FactoryBot.create(:api_backend)
    assert_equal([], api.sub_settings)

    attributes = api.serializable_hash
    attributes["sub_settings"] = [FactoryBot.attributes_for(:api_backend_sub_url_settings)]
    attributes["sub_settings"][0]["settings"] ||= {}
    attributes["sub_settings"][0]["settings"]["required_roles"] = ["test-role1", "test-role2"]
    attributes["sub_settings"][0]["settings"]["default_response_headers"] = [
      FactoryBot.attributes_for(:api_backend_http_header, :key => "X-SubDefault1"),
    ]
    attributes["sub_settings"][0]["settings"]["override_response_headers"] = [
      FactoryBot.attributes_for(:api_backend_http_header, :key => "X-SubOverride1"),
    ]
    attributes["sub_settings"][0]["settings"]["headers"] = [
      FactoryBot.attributes_for(:api_backend_http_header, :key => "X-SubHeader1"),
    ]
    attributes["sub_settings"][0]["settings"]["rate_limit_mode"] = "custom"
    attributes["sub_settings"][0]["settings"]["rate_limits"] = [
      FactoryBot.attributes_for(:rate_limit, :duration => 10000),
      FactoryBot.attributes_for(:rate_limit, :duration => 20000),
    ]
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{api.id}.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api => attributes),
    }))
    assert_response_code(204, response)

    api.reload
    assert_equal(1, api.sub_settings.length)
    assert_equal(["test-role1", "test-role2"].sort, api.sub_settings[0].settings.required_roles.sort)
    assert_equal(1, api.sub_settings[0].settings.default_response_headers.length)
    assert_equal("X-SubDefault1", api.sub_settings[0].settings.default_response_headers[0].key)
    assert_equal(1, api.sub_settings[0].settings.override_response_headers.length)
    assert_equal("X-SubOverride1", api.sub_settings[0].settings.override_response_headers[0].key)
    assert_equal(1, api.sub_settings[0].settings.headers.length)
    assert_equal("X-SubHeader1", api.sub_settings[0].settings.headers[0].key)
    assert_equal(2, api.sub_settings[0].settings.rate_limits.length)
    assert_equal(10000, api.sub_settings[0].settings.rate_limits[0].duration)
    assert_equal(20000, api.sub_settings[0].settings.rate_limits[1].duration)
  end

  def test_adds_rewrites
    api = FactoryBot.create(:api_backend)
    assert_equal([], api.rewrites)

    attributes = api.serializable_hash
    attributes["rewrites"] = [
      FactoryBot.attributes_for(:api_backend_rewrite, :backend_replacement => "/1"),
    ]
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{api.id}.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api => attributes),
    }))
    assert_response_code(204, response)

    api.reload
    assert_equal(1, api.rewrites.length)
    assert_equal("/1", api.rewrites[0].backend_replacement)
  end

  def test_updates_servers
    api = FactoryBot.create(:api_backend, {
      :servers => [FactoryBot.build(:api_backend_server, :host => "127.0.0.20")],
    })
    assert_equal(1, api.servers.length)
    assert_equal("127.0.0.20", api.servers[0].host)

    attributes = api.serializable_hash
    attributes["servers"][0]["host"] = "127.0.0.21"
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{api.id}.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api => attributes),
    }))
    assert_response_code(204, response)

    api.reload
    assert_equal(1, api.servers.length)
    assert_equal("127.0.0.21", api.servers[0].host)
  end

  def test_updates_url_matches
    api = FactoryBot.create(:api_backend, {
      :url_matches => [FactoryBot.build(:api_backend_url_match, :frontend_prefix => "/1")],
    })
    assert_equal(1, api.url_matches.length)
    assert_equal("/1", api.url_matches[0].frontend_prefix)

    attributes = api.serializable_hash
    attributes["url_matches"][0]["frontend_prefix"] = "/2"
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{api.id}.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api => attributes),
    }))
    assert_response_code(204, response)

    api.reload
    assert_equal(1, api.url_matches.length)
    assert_equal("/2", api.url_matches[0].frontend_prefix)
  end

  def test_updates_settings
    api = FactoryBot.create(:api_backend, {
      :settings => FactoryBot.build(:api_backend_settings, {
        :required_roles => ["test-role1"],
        :default_response_headers => [
          FactoryBot.build(:api_backend_http_header, :key => "X-Default1"),
        ],
        :override_response_headers => [
          FactoryBot.build(:api_backend_http_header, :key => "X-Override1"),
        ],
        :headers => [
          FactoryBot.build(:api_backend_http_header, :key => "X-Header1"),
        ],
        :rate_limit_mode => "custom",
        :rate_limits => [
          FactoryBot.build(:rate_limit, :duration => 1000),
          FactoryBot.build(:rate_limit, :duration => 2000),
        ],
      }),
    })
    assert_equal(["test-role1"].sort, api.settings.required_roles.sort)
    assert_equal(1, api.settings.default_response_headers.length)
    assert_equal("X-Default1", api.settings.default_response_headers[0].key)
    assert_equal(1, api.settings.override_response_headers.length)
    assert_equal("X-Override1", api.settings.override_response_headers[0].key)
    assert_equal(1, api.settings.headers.length)
    assert_equal("X-Header1", api.settings.headers[0].key)
    assert_equal(2, api.settings.rate_limits.length)
    assert_equal(1000, api.settings.rate_limits[0].duration)
    assert_equal(2000, api.settings.rate_limits[1].duration)

    attributes = api.serializable_hash
    attributes["settings"]["required_roles"] = ["test-role5", "test-role4"]
    attributes["settings"]["default_response_headers"][0]["key"] = "X-Default2"
    attributes["settings"]["override_response_headers"][0]["key"] = "X-Override2"
    attributes["settings"]["headers"][0]["key"] = "X-Header2"
    attributes["settings"]["rate_limits"][0]["duration"] = 5000
    attributes["settings"]["rate_limits"][1]["duration"] = 7500
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{api.id}.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api => attributes),
    }))
    assert_response_code(204, response)

    api.reload
    assert_equal(["test-role5", "test-role4"].sort, api.settings.required_roles.sort)
    assert_equal(1, api.settings.default_response_headers.length)
    assert_equal("X-Default2", api.settings.default_response_headers[0].key)
    assert_equal(1, api.settings.override_response_headers.length)
    assert_equal("X-Override2", api.settings.override_response_headers[0].key)
    assert_equal(1, api.settings.headers.length)
    assert_equal("X-Header2", api.settings.headers[0].key)
    assert_equal(2, api.settings.rate_limits.length)
    assert_equal(attributes["settings"]["rate_limits"][0]["id"], api.settings.rate_limits[0].id)
    assert_equal(5000, api.settings.rate_limits[0].duration)
    assert_equal(attributes["settings"]["rate_limits"][1]["id"], api.settings.rate_limits[1].id)
    assert_equal(7500, api.settings.rate_limits[1].duration)
  end

  def test_updates_sub_settings
    api = FactoryBot.create(:api_backend, {
      :sub_settings => [
        FactoryBot.build(:api_backend_sub_url_settings, {
          :settings => FactoryBot.build(:api_backend_settings, {
            :required_roles => ["test-role1"],
            :default_response_headers => [
              FactoryBot.build(:api_backend_http_header, :key => "X-SubDefault1"),
            ],
            :override_response_headers => [
              FactoryBot.build(:api_backend_http_header, :key => "X-SubOverride1"),
            ],
            :headers => [
              FactoryBot.build(:api_backend_http_header, :key => "X-SubHeader1"),
            ],
            :rate_limit_mode => "custom",
            :rate_limits => [
              FactoryBot.build(:rate_limit, :duration => 1000),
              FactoryBot.build(:rate_limit, :duration => 2000),
            ],
          }),
        }),
      ],
    })
    assert_equal(1, api.sub_settings.length)
    assert_equal(["test-role1"].sort, api.sub_settings[0].settings.required_roles.sort)
    assert_equal(1, api.sub_settings[0].settings.default_response_headers.length)
    assert_equal("X-SubDefault1", api.sub_settings[0].settings.default_response_headers[0].key)
    assert_equal(1, api.sub_settings[0].settings.override_response_headers.length)
    assert_equal("X-SubOverride1", api.sub_settings[0].settings.override_response_headers[0].key)
    assert_equal(1, api.sub_settings[0].settings.headers.length)
    assert_equal("X-SubHeader1", api.sub_settings[0].settings.headers[0].key)
    assert_equal(2, api.sub_settings[0].settings.rate_limits.length)
    assert_equal(1000, api.sub_settings[0].settings.rate_limits[0].duration)
    assert_equal(2000, api.sub_settings[0].settings.rate_limits[1].duration)

    attributes = api.serializable_hash
    attributes["sub_settings"][0]["settings"]["required_roles"] = ["test-role3", "test-role4"]
    attributes["sub_settings"][0]["settings"]["default_response_headers"][0]["key"] = "X-SubDefault2"
    attributes["sub_settings"][0]["settings"]["override_response_headers"][0]["key"] = "X-SubOverride2"
    attributes["sub_settings"][0]["settings"]["headers"][0]["key"] = "X-SubHeader2"
    attributes["sub_settings"][0]["settings"]["rate_limits"][0]["duration"] = 10000
    attributes["sub_settings"][0]["settings"]["rate_limits"][1]["duration"] = 20000
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{api.id}.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api => attributes),
    }))
    assert_response_code(204, response)

    api.reload
    assert_equal(1, api.sub_settings.length)
    assert_equal(["test-role3", "test-role4"].sort, api.sub_settings[0].settings.required_roles.sort)
    assert_equal(1, api.sub_settings[0].settings.default_response_headers.length)
    assert_equal("X-SubDefault2", api.sub_settings[0].settings.default_response_headers[0].key)
    assert_equal(1, api.sub_settings[0].settings.override_response_headers.length)
    assert_equal("X-SubOverride2", api.sub_settings[0].settings.override_response_headers[0].key)
    assert_equal(1, api.sub_settings[0].settings.headers.length)
    assert_equal("X-SubHeader2", api.sub_settings[0].settings.headers[0].key)
    assert_equal(2, api.sub_settings[0].settings.rate_limits.length)
    assert_equal(10000, api.sub_settings[0].settings.rate_limits[0].duration)
    assert_equal(20000, api.sub_settings[0].settings.rate_limits[1].duration)
  end

  def test_updates_rewrites
    api = FactoryBot.create(:api_backend, {
      :rewrites => [FactoryBot.build(:api_backend_rewrite, :backend_replacement => "/1")],
    })
    assert_equal(1, api.rewrites.length)
    assert_equal("/1", api.rewrites[0].backend_replacement)

    attributes = api.serializable_hash
    attributes["rewrites"][0]["backend_replacement"] = "/2"
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{api.id}.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api => attributes),
    }))
    assert_response_code(204, response)

    api.reload
    assert_equal(1, api.rewrites.length)
    assert_equal("/2", api.rewrites[0].backend_replacement)
  end

  def test_removes_single_value_servers
    api = FactoryBot.create(:api_backend, {
      :servers => [
        FactoryBot.build(:api_backend_server, :host => "127.0.0.20"),
        FactoryBot.build(:api_backend_server, :host => "127.0.0.21"),
      ],
    })
    assert_equal(2, api.servers.length)
    assert_equal("127.0.0.20", api.servers[0].host)
    assert_equal("127.0.0.21", api.servers[1].host)

    attributes = api.serializable_hash
    attributes["servers"].shift
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{api.id}.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api => attributes),
    }))
    assert_response_code(204, response)

    api.reload
    assert_equal(1, api.servers.length)
    assert_equal("127.0.0.21", api.servers[0].host)
  end

  def test_removes_single_value_url_matches
    api = FactoryBot.create(:api_backend, {
      :url_matches => [
        FactoryBot.build(:api_backend_url_match, :frontend_prefix => "/1"),
        FactoryBot.build(:api_backend_url_match, :frontend_prefix => "/2"),
      ],
    })
    assert_equal(2, api.url_matches.length)
    assert_equal("/1", api.url_matches[0].frontend_prefix)
    assert_equal("/2", api.url_matches[1].frontend_prefix)

    attributes = api.serializable_hash
    attributes["url_matches"].shift
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{api.id}.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api => attributes),
    }))
    assert_response_code(204, response)

    api.reload
    assert_equal(1, api.url_matches.length)
    assert_equal("/2", api.url_matches[0].frontend_prefix)
  end

  def test_removes_single_value_settings
    api = FactoryBot.create(:api_backend, {
      :settings => FactoryBot.build(:api_backend_settings, {
        :required_roles => ["test-role1", "test-role2"],
        :default_response_headers => [
          FactoryBot.build(:api_backend_http_header, :key => "X-Default1"),
          FactoryBot.build(:api_backend_http_header, :key => "X-Default2"),
        ],
        :override_response_headers => [
          FactoryBot.build(:api_backend_http_header, :key => "X-Override1"),
          FactoryBot.build(:api_backend_http_header, :key => "X-Override2"),
        ],
        :headers => [
          FactoryBot.build(:api_backend_http_header, :key => "X-Header1"),
          FactoryBot.build(:api_backend_http_header, :key => "X-Header2"),
        ],
        :rate_limit_mode => "custom",
        :rate_limits => [
          FactoryBot.build(:rate_limit, :duration => 1000),
          FactoryBot.build(:rate_limit, :duration => 2000),
        ],
      }),
    })
    assert_equal(["test-role1", "test-role2"].sort, api.settings.required_roles.sort)
    assert_equal(2, api.settings.default_response_headers.length)
    assert_equal("X-Default1", api.settings.default_response_headers[0].key)
    assert_equal("X-Default2", api.settings.default_response_headers[1].key)
    assert_equal(2, api.settings.override_response_headers.length)
    assert_equal("X-Override1", api.settings.override_response_headers[0].key)
    assert_equal("X-Override2", api.settings.override_response_headers[1].key)
    assert_equal(2, api.settings.headers.length)
    assert_equal("X-Header1", api.settings.headers[0].key)
    assert_equal("X-Header2", api.settings.headers[1].key)
    assert_equal(2, api.settings.rate_limits.length)
    assert_equal(1000, api.settings.rate_limits[0].duration)
    assert_equal(2000, api.settings.rate_limits[1].duration)

    attributes = api.serializable_hash
    attributes["settings"]["required_roles"].shift
    attributes["settings"]["default_response_headers"].shift
    attributes["settings"]["override_response_headers"].shift
    attributes["settings"]["headers"].shift
    attributes["settings"]["rate_limits"].shift
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{api.id}.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api => attributes),
    }))
    assert_response_code(204, response)

    api.reload
    assert_equal(["test-role2"].sort, api.settings.required_roles.sort)
    assert_equal(1, api.settings.default_response_headers.length)
    assert_equal("X-Default2", api.settings.default_response_headers[0].key)
    assert_equal(1, api.settings.override_response_headers.length)
    assert_equal("X-Override2", api.settings.override_response_headers[0].key)
    assert_equal(1, api.settings.headers.length)
    assert_equal("X-Header2", api.settings.headers[0].key)
    assert_equal(1, api.settings.rate_limits.length)
    assert_equal(attributes["settings"]["rate_limits"][0]["id"], api.settings.rate_limits[0].id)
    assert_equal(2000, api.settings.rate_limits[0].duration)
  end

  def test_removes_single_value_sub_settings
    api = FactoryBot.create(:api_backend, {
      :sub_settings => [
        FactoryBot.build(:api_backend_sub_url_settings),
        FactoryBot.build(:api_backend_sub_url_settings, {
          :settings => FactoryBot.build(:api_backend_settings, {
            :required_roles => ["test-role1", "test-role2"],
            :default_response_headers => [
              FactoryBot.build(:api_backend_http_header, :key => "X-SubDefault1"),
              FactoryBot.build(:api_backend_http_header, :key => "X-SubDefault2"),
            ],
            :override_response_headers => [
              FactoryBot.build(:api_backend_http_header, :key => "X-SubOverride1"),
              FactoryBot.build(:api_backend_http_header, :key => "X-SubOverride2"),
            ],
            :headers => [
              FactoryBot.build(:api_backend_http_header, :key => "X-SubHeader1"),
              FactoryBot.build(:api_backend_http_header, :key => "X-SubHeader2"),
            ],
            :rate_limit_mode => "custom",
            :rate_limits => [
              FactoryBot.build(:rate_limit, :duration => 1000),
              FactoryBot.build(:rate_limit, :duration => 2000),
            ],
          }),
        }),
      ],
    })
    assert_equal(2, api.sub_settings.length)
    assert_equal(["test-role1", "test-role2"].sort, api.sub_settings[1].settings.required_roles.sort)
    assert_equal(2, api.sub_settings[1].settings.default_response_headers.length)
    assert_equal("X-SubDefault1", api.sub_settings[1].settings.default_response_headers[0].key)
    assert_equal("X-SubDefault2", api.sub_settings[1].settings.default_response_headers[1].key)
    assert_equal(2, api.sub_settings[1].settings.override_response_headers.length)
    assert_equal("X-SubOverride1", api.sub_settings[1].settings.override_response_headers[0].key)
    assert_equal("X-SubOverride2", api.sub_settings[1].settings.override_response_headers[1].key)
    assert_equal(2, api.sub_settings[1].settings.headers.length)
    assert_equal("X-SubHeader1", api.sub_settings[1].settings.headers[0].key)
    assert_equal("X-SubHeader2", api.sub_settings[1].settings.headers[1].key)
    assert_equal(2, api.sub_settings[1].settings.rate_limits.length)
    assert_equal(1000, api.sub_settings[1].settings.rate_limits[0].duration)
    assert_equal(2000, api.sub_settings[1].settings.rate_limits[1].duration)

    attributes = api.serializable_hash
    # Remove 1 sub-settings record and make updates to the other. By default,
    # Mongoid doesn't handle this type of save, so this also tests our
    # workaround (see Api#save): https://jira.mongodb.org/browse/MONGOID-3964
    attributes["sub_settings"].shift
    attributes["sub_settings"][0]["settings"]["required_roles"].shift
    attributes["sub_settings"][0]["settings"]["default_response_headers"].shift
    attributes["sub_settings"][0]["settings"]["override_response_headers"].shift
    attributes["sub_settings"][0]["settings"]["headers"].shift
    attributes["sub_settings"][0]["settings"]["rate_limits"].shift
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{api.id}.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api => attributes),
    }))
    assert_response_code(204, response)

    api.reload
    assert_equal(1, api.sub_settings.length)
    assert_equal(["test-role2"].sort, api.sub_settings[0].settings.required_roles.sort)
    assert_equal(1, api.sub_settings[0].settings.default_response_headers.length)
    assert_equal("X-SubDefault2", api.sub_settings[0].settings.default_response_headers[0].key)
    assert_equal(1, api.sub_settings[0].settings.override_response_headers.length)
    assert_equal("X-SubOverride2", api.sub_settings[0].settings.override_response_headers[0].key)
    assert_equal(1, api.sub_settings[0].settings.headers.length)
    assert_equal("X-SubHeader2", api.sub_settings[0].settings.headers[0].key)
    assert_equal(1, api.sub_settings[0].settings.rate_limits.length)
    assert_equal(2000, api.sub_settings[0].settings.rate_limits[0].duration)
  end

  def test_removes_single_value_rewrites
    api = FactoryBot.create(:api_backend, {
      :rewrites => [
        FactoryBot.build(:api_backend_rewrite, :backend_replacement => "/1"),
        FactoryBot.build(:api_backend_rewrite, :backend_replacement => "/2"),
      ],
    })
    assert_equal(2, api.rewrites.length)
    assert_equal("/1", api.rewrites[0].backend_replacement)
    assert_equal("/2", api.rewrites[1].backend_replacement)

    attributes = api.serializable_hash
    attributes["rewrites"].shift
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{api.id}.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api => attributes),
    }))
    assert_response_code(204, response)

    api.reload
    assert_equal(1, api.rewrites.length)
    assert_equal("/2", api.rewrites[0].backend_replacement)
  end

  [nil, []].each do |empty_value|
    empty_method_name =
      case(empty_value)
      when nil
        "null"
      when []
        "empty_array"
      end

    define_method("test_removes_#{empty_method_name}_servers") do
      api = FactoryBot.create(:api_backend, {
        :servers => [FactoryBot.build(:api_backend_server, :host => "127.0.0.20")],
      })
      assert_equal(1, api.servers.length)
      assert_equal("127.0.0.20", api.servers[0].host)

      attributes = api.serializable_hash
      attributes["servers"] = empty_value
      response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{api.id}.json", http_options.deep_merge(admin_token).deep_merge({
        :headers => { "Content-Type" => "application/json" },
        :body => MultiJson.dump(:api => attributes),
      }))
      assert_response_code(422, response)
      data = MultiJson.load(response.body)
      assert_equal({
        "errors" => {
          "base" => ["Must have at least one servers"],
        },
      }, data)

      api.reload
      assert_equal(1, api.servers.length)
      assert_equal("127.0.0.20", api.servers[0].host)
    end

    define_method("test_removes_#{empty_method_name}_url_matches") do
      api = FactoryBot.create(:api_backend, {
        :url_matches => [FactoryBot.build(:api_backend_url_match, :frontend_prefix => "/1")],
      })
      assert_equal(1, api.url_matches.length)
      assert_equal("/1", api.url_matches[0].frontend_prefix)

      attributes = api.serializable_hash
      attributes["url_matches"] = empty_value
      response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{api.id}.json", http_options.deep_merge(admin_token).deep_merge({
        :headers => { "Content-Type" => "application/json" },
        :body => MultiJson.dump(:api => attributes),
      }))
      assert_response_code(422, response)
      data = MultiJson.load(response.body)
      assert_equal({
        "errors" => {
          "base" => ["Must have at least one url_matches"],
        },
      }, data)

      api.reload
      assert_equal(1, api.url_matches.length)
      assert_equal("/1", api.url_matches[0].frontend_prefix)
    end

    define_method("test_removes_#{empty_method_name}_settings") do
      api = FactoryBot.create(:api_backend, {
        :settings => FactoryBot.build(:api_backend_settings, {
          :required_roles => ["test-role1"],
          :default_response_headers => [
            FactoryBot.build(:api_backend_http_header, :key => "X-Default1"),
          ],
          :override_response_headers => [
            FactoryBot.build(:api_backend_http_header, :key => "X-Override1"),
          ],
          :headers => [
            FactoryBot.build(:api_backend_http_header, :key => "X-Header1"),
          ],
          :rate_limit_mode => "custom",
          :rate_limits => [
            FactoryBot.build(:rate_limit, :duration => 1000),
            FactoryBot.build(:rate_limit, :duration => 2000),
          ],
        }),
      })
      assert_equal(["test-role1"].sort, api.settings.required_roles.sort)
      assert_equal(1, api.settings.default_response_headers.length)
      assert_equal("X-Default1", api.settings.default_response_headers[0].key)
      assert_equal(1, api.settings.override_response_headers.length)
      assert_equal("X-Override1", api.settings.override_response_headers[0].key)
      assert_equal(1, api.settings.headers.length)
      assert_equal("X-Header1", api.settings.headers[0].key)
      assert_equal(2, api.settings.rate_limits.length)
      assert_equal(1000, api.settings.rate_limits[0].duration)
      assert_equal(2000, api.settings.rate_limits[1].duration)

      attributes = api.serializable_hash
      attributes["settings"]["required_roles"] = empty_value
      attributes["settings"]["default_response_headers"] = empty_value
      attributes["settings"]["override_response_headers"] = empty_value
      attributes["settings"]["headers"] = empty_value
      attributes["settings"]["rate_limits"] = empty_value
      response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{api.id}.json", http_options.deep_merge(admin_token).deep_merge({
        :headers => { "Content-Type" => "application/json" },
        :body => MultiJson.dump(:api => attributes),
      }))
      assert_response_code(204, response)

      api.reload
      assert_equal([], api.settings.required_roles)
      assert_equal([], api.settings.default_response_headers)
      assert_equal([], api.settings.override_response_headers)
      assert_equal([], api.settings.headers)
      assert_equal([], api.settings.rate_limits)
    end

    define_method("test_removes_#{empty_method_name}_sub_settings") do
      api = FactoryBot.create(:api_backend, {
        :sub_settings => [FactoryBot.build(:api_backend_sub_url_settings)],
      })
      assert_equal(1, api.sub_settings.length)

      attributes = api.serializable_hash
      attributes["sub_settings"] = empty_value
      response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{api.id}.json", http_options.deep_merge(admin_token).deep_merge({
        :headers => { "Content-Type" => "application/json" },
        :body => MultiJson.dump(:api => attributes),
      }))
      assert_response_code(204, response)

      api.reload
      assert_equal([], api.sub_settings)
    end

    define_method("test_removes_#{empty_method_name}_sub_settings_embedded_settings") do
      api = FactoryBot.create(:api_backend, {
        :sub_settings => [
          FactoryBot.build(:api_backend_sub_url_settings, {
            :settings => FactoryBot.build(:api_backend_settings, {
              :required_roles => ["test-role1"],
              :default_response_headers => [
                FactoryBot.build(:api_backend_http_header, :key => "X-SubDefault1"),
              ],
              :override_response_headers => [
                FactoryBot.build(:api_backend_http_header, :key => "X-SubOverride1"),
              ],
              :headers => [
                FactoryBot.build(:api_backend_http_header, :key => "X-SubHeader1"),
              ],
              :rate_limit_mode => "custom",
              :rate_limits => [
                FactoryBot.build(:rate_limit, :duration => 1000),
                FactoryBot.build(:rate_limit, :duration => 2000),
              ],
            }),
          }),
        ],
      })
      assert_equal(1, api.sub_settings.length)
      assert_equal(["test-role1"].sort, api.sub_settings[0].settings.required_roles.sort)
      assert_equal(1, api.sub_settings[0].settings.default_response_headers.length)
      assert_equal("X-SubDefault1", api.sub_settings[0].settings.default_response_headers[0].key)
      assert_equal(1, api.sub_settings[0].settings.override_response_headers.length)
      assert_equal("X-SubOverride1", api.sub_settings[0].settings.override_response_headers[0].key)
      assert_equal(1, api.sub_settings[0].settings.headers.length)
      assert_equal("X-SubHeader1", api.sub_settings[0].settings.headers[0].key)
      assert_equal(2, api.sub_settings[0].settings.rate_limits.length)
      assert_equal(1000, api.sub_settings[0].settings.rate_limits[0].duration)
      assert_equal(2000, api.sub_settings[0].settings.rate_limits[1].duration)

      attributes = api.serializable_hash
      attributes["sub_settings"][0]["settings"]["required_roles"] = empty_value
      attributes["sub_settings"][0]["settings"]["default_response_headers"] = empty_value
      attributes["sub_settings"][0]["settings"]["override_response_headers"] = empty_value
      attributes["sub_settings"][0]["settings"]["headers"] = empty_value
      attributes["sub_settings"][0]["settings"]["rate_limits"] = empty_value
      response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{api.id}.json", http_options.deep_merge(admin_token).deep_merge({
        :headers => { "Content-Type" => "application/json" },
        :body => MultiJson.dump(:api => attributes),
      }))
      assert_response_code(204, response)

      api.reload
      assert_equal([], api.sub_settings[0].settings.required_roles)
      assert_equal([], api.sub_settings[0].settings.default_response_headers)
      assert_equal([], api.sub_settings[0].settings.override_response_headers)
      assert_equal([], api.sub_settings[0].settings.headers)
      assert_equal([], api.sub_settings[0].settings.rate_limits)
    end

    define_method("test_removes_#{empty_method_name}_rewrites") do
      api = FactoryBot.create(:api_backend, {
        :rewrites => [FactoryBot.build(:api_backend_rewrite, :backend_replacement => "/1")],
      })
      assert_equal(1, api.rewrites.length)
      assert_equal("/1", api.rewrites[0].backend_replacement)

      attributes = api.serializable_hash
      attributes["rewrites"] = empty_value
      response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{api.id}.json", http_options.deep_merge(admin_token).deep_merge({
        :headers => { "Content-Type" => "application/json" },
        :body => MultiJson.dump(:api => attributes),
      }))
      assert_response_code(204, response)

      api.reload
      assert_equal([], api.rewrites)
    end
  end

  def test_keeps_not_present_keys_servers
    api = FactoryBot.create(:api_backend, {
      :servers => [FactoryBot.build(:api_backend_server, :host => "127.0.0.20")],
    })
    refute_equal("Updated", api.name)
    assert_equal(1, api.servers.length)
    assert_equal("127.0.0.20", api.servers[0].host)

    attributes = api.serializable_hash
    attributes["name"] = "Updated"
    attributes.delete("servers")
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{api.id}.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api => attributes),
    }))
    assert_response_code(204, response)

    api.reload
    assert_equal("Updated", api.name)
    assert_equal(1, api.servers.length)
    assert_equal("127.0.0.20", api.servers[0].host)
  end

  def test_keeps_not_present_keys_url_matches
    api = FactoryBot.create(:api_backend, {
      :url_matches => [FactoryBot.build(:api_backend_url_match, :frontend_prefix => "/1")],
    })
    refute_equal("Updated", api.name)
    assert_equal(1, api.url_matches.length)
    assert_equal("/1", api.url_matches[0].frontend_prefix)

    attributes = api.serializable_hash
    attributes["name"] = "Updated"
    attributes.delete("url_matches")
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{api.id}.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api => attributes),
    }))
    assert_response_code(204, response)

    api.reload
    assert_equal("Updated", api.name)
    assert_equal(1, api.url_matches.length)
    assert_equal("/1", api.url_matches[0].frontend_prefix)
  end

  def test_keeps_not_present_keys_settings
    api = FactoryBot.create(:api_backend, {
      :settings => FactoryBot.build(:api_backend_settings, {
        :required_roles => ["test-role1"],
        :default_response_headers => [
          FactoryBot.build(:api_backend_http_header, :key => "X-Default1"),
        ],
        :override_response_headers => [
          FactoryBot.build(:api_backend_http_header, :key => "X-Override1"),
        ],
        :headers => [
          FactoryBot.build(:api_backend_http_header, :key => "X-Header1"),
        ],
        :rate_limit_mode => "custom",
        :rate_limits => [
          FactoryBot.build(:rate_limit, :duration => 1000),
          FactoryBot.build(:rate_limit, :duration => 2000),
        ],
      }),
    })
    refute_equal("Updated", api.name)
    assert_equal(["test-role1"].sort, api.settings.required_roles.sort)
    assert_equal(1, api.settings.default_response_headers.length)
    assert_equal("X-Default1", api.settings.default_response_headers[0].key)
    assert_equal(1, api.settings.override_response_headers.length)
    assert_equal("X-Override1", api.settings.override_response_headers[0].key)
    assert_equal(1, api.settings.headers.length)
    assert_equal("X-Header1", api.settings.headers[0].key)
    assert_equal(2, api.settings.rate_limits.length)
    assert_equal(1000, api.settings.rate_limits[0].duration)
    assert_equal(2000, api.settings.rate_limits[1].duration)

    attributes = api.serializable_hash
    attributes["name"] = "Updated"
    attributes["settings"].delete("required_roles")
    attributes["settings"].delete("default_response_headers")
    attributes["settings"].delete("override_response_headers")
    attributes["settings"].delete("headers")
    attributes["settings"].delete("rate_limits")
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{api.id}.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api => attributes),
    }))
    assert_response_code(204, response)

    api.reload
    assert_equal("Updated", api.name)
    assert_equal(["test-role1"].sort, api.settings.required_roles.sort)
    assert_equal(1, api.settings.default_response_headers.length)
    assert_equal("X-Default1", api.settings.default_response_headers[0].key)
    assert_equal(1, api.settings.override_response_headers.length)
    assert_equal("X-Override1", api.settings.override_response_headers[0].key)
    assert_equal(1, api.settings.headers.length)
    assert_equal("X-Header1", api.settings.headers[0].key)
    assert_equal(2, api.settings.rate_limits.length)
    assert_equal(1000, api.settings.rate_limits[0].duration)
    assert_equal(2000, api.settings.rate_limits[1].duration)
  end

  def test_keeps_not_present_keys_sub_settings
    api = FactoryBot.create(:api_backend, {
      :sub_settings => [FactoryBot.build(:api_backend_sub_url_settings)],
    })
    refute_equal("Updated", api.name)
    assert_equal(1, api.sub_settings.length)

    attributes = api.serializable_hash
    attributes["name"] = "Updated"
    attributes.delete("sub_settings")
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{api.id}.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api => attributes),
    }))
    assert_response_code(204, response)

    api.reload
    assert_equal("Updated", api.name)
    assert_equal(1, api.sub_settings.length)
  end

  def test_keeps_not_present_keys_settings_embedded_settings
    api = FactoryBot.create(:api_backend, {
      :sub_settings => [
        FactoryBot.build(:api_backend_sub_url_settings, {
          :settings => FactoryBot.build(:api_backend_settings, {
            :required_roles => ["test-role1"],
            :default_response_headers => [
              FactoryBot.build(:api_backend_http_header, :key => "X-SubDefault1"),
            ],
            :override_response_headers => [
              FactoryBot.build(:api_backend_http_header, :key => "X-SubOverride1"),
            ],
            :headers => [
              FactoryBot.build(:api_backend_http_header, :key => "X-SubHeader1"),
            ],
            :rate_limit_mode => "custom",
            :rate_limits => [
              FactoryBot.build(:rate_limit, :duration => 1000),
              FactoryBot.build(:rate_limit, :duration => 2000),
            ],
          }),
        }),
      ],
    })
    refute_equal("Updated", api.name)
    assert_equal(1, api.sub_settings.length)
    assert_equal(["test-role1"].sort, api.sub_settings[0].settings.required_roles.sort)
    assert_equal(1, api.sub_settings[0].settings.default_response_headers.length)
    assert_equal("X-SubDefault1", api.sub_settings[0].settings.default_response_headers[0].key)
    assert_equal(1, api.sub_settings[0].settings.override_response_headers.length)
    assert_equal("X-SubOverride1", api.sub_settings[0].settings.override_response_headers[0].key)
    assert_equal(1, api.sub_settings[0].settings.headers.length)
    assert_equal("X-SubHeader1", api.sub_settings[0].settings.headers[0].key)
    assert_equal(2, api.sub_settings[0].settings.rate_limits.length)
    assert_equal(1000, api.sub_settings[0].settings.rate_limits[0].duration)
    assert_equal(2000, api.sub_settings[0].settings.rate_limits[1].duration)

    attributes = api.serializable_hash
    attributes["name"] = "Updated"
    attributes["sub_settings"][0]["settings"].delete("required_roles")
    attributes["sub_settings"][0]["settings"].delete("default_response_headers")
    attributes["sub_settings"][0]["settings"].delete("override_response_headers")
    attributes["sub_settings"][0]["settings"].delete("headers")
    attributes["sub_settings"][0]["settings"].delete("rate_limits")
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{api.id}.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api => attributes),
    }))
    assert_response_code(204, response)

    api.reload
    assert_equal(1, api.sub_settings.length)
    assert_equal(["test-role1"].sort, api.sub_settings[0].settings.required_roles.sort)
    assert_equal(1, api.sub_settings[0].settings.default_response_headers.length)
    assert_equal("X-SubDefault1", api.sub_settings[0].settings.default_response_headers[0].key)
    assert_equal(1, api.sub_settings[0].settings.override_response_headers.length)
    assert_equal("X-SubOverride1", api.sub_settings[0].settings.override_response_headers[0].key)
    assert_equal(1, api.sub_settings[0].settings.headers.length)
    assert_equal("X-SubHeader1", api.sub_settings[0].settings.headers[0].key)
    assert_equal(2, api.sub_settings[0].settings.rate_limits.length)
    assert_equal(1000, api.sub_settings[0].settings.rate_limits[0].duration)
    assert_equal(2000, api.sub_settings[0].settings.rate_limits[1].duration)
  end

  def test_keeps_not_present_keys_rewrites
    api = FactoryBot.create(:api_backend, {
      :rewrites => [FactoryBot.build(:api_backend_rewrite, :backend_replacement => "/1")],
    })
    refute_equal("Updated", api.name)
    assert_equal(1, api.rewrites.length)
    assert_equal("/1", api.rewrites[0].backend_replacement)

    attributes = api.serializable_hash
    attributes["name"] = "Updated"
    attributes.delete("rewrites")
    response = Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{api.id}.json", http_options.deep_merge(admin_token).deep_merge({
      :headers => { "Content-Type" => "application/json" },
      :body => MultiJson.dump(:api => attributes),
    }))
    assert_response_code(204, response)

    api.reload
    assert_equal("Updated", api.name)
    assert_equal(1, api.rewrites.length)
    assert_equal("/1", api.rewrites[0].backend_replacement)
  end
end
