module ApiUmbrellaTestHelpers
  module ApiSaveValidations
    private

    def assert_valid(overrides)
      assert_valid_create(overrides)
      assert_valid_update(overrides)
    end

    def assert_valid_create(overrides)
      assert_valid_action(:create, overrides)
    end

    def assert_valid_update(overrides)
      assert_valid_action(:update, overrides)
    end

    def assert_valid_action(action, overrides)
      attributes = attributes_for(action).deep_merge(overrides.deep_stringify_keys)

      response = create_or_update(action, attributes)
      if(action == :create)
        assert_response_code(201, response)
      elsif(action == :update)
        assert_response_code(204, response)
      end
    end

    def assert_invalid(overrides, expected_error_fields)
      assert_invalid_create(overrides, expected_error_fields)
      assert_invalid_update(overrides, expected_error_fields)
    end

    def assert_invalid_create(overrides, expected_error_fields)
      assert_invalid_action(:create, overrides, expected_error_fields)
    end

    def assert_invalid_update(overrides, expected_error_fields)
      assert_invalid_action(:update, overrides, expected_error_fields)
    end

    def assert_invalid_action(action, overrides, expected_error_fields)
      attributes = attributes_for(action).deep_merge(overrides.deep_stringify_keys)

      response = create_or_update(action, attributes)
      assert_response_code(422, response)
      data = MultiJson.load(response.body)
      assert_equal(["errors"], data.keys)
      assert_equal(expected_error_fields.sort, data["errors"].keys.sort)
    end

    def attributes_for(action)
      if(action == :create)
        FactoryBot.attributes_for(:api).deep_stringify_keys
      elsif(action == :update)
        FactoryBot.create(:api).serializable_hash
      else
        flunk("Unknown action: #{action.inspect}")
      end
    end

    def create_or_update(action, attributes)
      if(action == :create)
        Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/apis.json", http_options.deep_merge(admin_token).deep_merge({
          :headers => { "Content-Type" => "application/json" },
          :body => MultiJson.dump(:api => attributes),
        }))
      elsif(action == :update)
        Typhoeus.put("https://127.0.0.1:9081/api-umbrella/v1/apis/#{attributes["id"]}.json", http_options.deep_merge(admin_token).deep_merge({
          :headers => { "Content-Type" => "application/json" },
          :body => MultiJson.dump(:api => attributes),
        }))
      else
        flunk("Unknown action: #{action.inspect}")
      end
    end
  end
end
