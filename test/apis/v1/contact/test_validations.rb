require_relative "../../../test_helper"

class Test::Apis::V1::Contact::TestValidations < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
  end

  def test_required
    response = make_request({})
    assert_response_code(422, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)
    assert_equal([
      {
        "code" => "INVALID_INPUT",
        "message" => "Provide your name.",
        "field" => "name",
        "full_message" => "Name: Provide your name.",
      },
      {
        "code" => "INVALID_INPUT",
        "message" => "Provide your email address.",
        "field" => "email",
        "full_message" => "Email: Provide your email address.",
      },
      {
        "code" => "INVALID_INPUT",
        "message" => "Provide the API.",
        "field" => "api",
        "full_message" => "API: Provide the API.",
      },
      {
        "code" => "INVALID_INPUT",
        "message" => "Provide a subject.",
        "field" => "subject",
        "full_message" => "Subject: Provide a subject.",
      },
      {
        "code" => "INVALID_INPUT",
        "message" => "Provide a message.",
        "field" => "message",
        "full_message" => "Message: Provide a message.",
      },
    ].sort_by { |e| e["full_message"] }, data["errors"].sort_by { |e| e["full_message"] })
  end

  def test_email_format
    response = make_request({
      :name => "Foo",
      :email => "foo@example",
      :api => "Example API",
      :subject => "Support",
      :message => "Message body",
    })
    assert_response_code(422, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)
    assert_equal([
      {
        "code" => "INVALID_INPUT",
        "message" => "is invalid",
        "field" => "email",
        "full_message" => "Email: is invalid",
      },
    ], data["errors"])
  end

  def test_email_format_configurable
    params = {
      :name => "Foo",
      :email => "foo@example.com",
      :api => "Example API",
      :subject => "Support",
      :message => "Message body",
    }

    response = make_request(params.merge({
      :email => "foo@example.com",
    }))
    assert_response_code(200, response)

    response = make_request(params.merge({
      :email => "foo@EXAMPLE.COM",
    }))
    assert_response_code(200, response)

    override_config({
      "web" => {
        "contact" => {
          "email_regex" => "\\A[^@\\s]+@(?!example\\.com)[^@\\s]+\\.[^@\\s]+\\z",
        },
      },
    }) do
      response = make_request(params.merge({
        :email => "foo@example.com",
      }))
      assert_response_code(422, response)
      data = MultiJson.load(response.body)
      assert_equal({
        "errors" => [{
          "code" => "INVALID_INPUT",
          "field" => "email",
          "message" => "is invalid",
          "full_message" => "Email: is invalid",
        }],
      }, data)

      response = make_request(params.merge({
        :email => "foo@EXAMPLE.COM",
      }))
      assert_response_code(422, response)
      data = MultiJson.load(response.body)
      assert_equal({
        "errors" => [{
          "code" => "INVALID_INPUT",
          "field" => "email",
          "message" => "is invalid",
          "full_message" => "Email: is invalid",
        }],
      }, data)
    end
  end

  def test_name_format
    response = make_request({
      :name => "<",
      :email => "foo@example.com",
      :api => "Example API",
      :subject => "Support",
      :message => "Message body",
    })
    assert_response_code(422, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)
    assert_equal([
      {
        "code" => "INVALID_INPUT",
        "message" => "is invalid",
        "field" => "name",
        "full_message" => "Name: is invalid",
      },
    ], data["errors"])
  end

  def test_name_format_configurable
    params = {
      :name => "Foo",
      :email => "foo@example.com",
      :api => "Example API",
      :subject => "Support",
      :message => "Message body",
    }

    response = make_request(params.merge({
      :name => "foo",
    }))
    assert_response_code(200, response)

    response = make_request(params.merge({
      :name => "FOO",
    }))
    assert_response_code(200, response)

    override_config({
      "web" => {
        "contact" => {
          "name_exclude_regex" => "oo",
        },
      },
    }) do
      response = make_request(params.merge({
        :name => "foo",
      }))
      assert_response_code(422, response)
      data = MultiJson.load(response.body)
      assert_equal({
        "errors" => [{
          "code" => "INVALID_INPUT",
          "field" => "name",
          "message" => "is invalid",
          "full_message" => "Name: is invalid",
        }],
      }, data)

      response = make_request(params.merge({
        :name => "FOO",
      }))
      assert_response_code(422, response)
      data = MultiJson.load(response.body)
      assert_equal({
        "errors" => [{
          "code" => "INVALID_INPUT",
          "field" => "name",
          "message" => "is invalid",
          "full_message" => "Name: is invalid",
        }],
      }, data)
    end
  end

  def test_api_format
    response = make_request({
      :name => "Foo",
      :email => "foo@example.com",
      :api => "<script",
      :subject => "Support",
      :message => "Message body",
    })
    assert_response_code(422, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)
    assert_equal([
      {
        "code" => "INVALID_INPUT",
        "message" => "is invalid",
        "field" => "api",
        "full_message" => "API: is invalid",
      },
    ], data["errors"])
  end

  def test_api_format_configurable
    params = {
      :name => "Foo",
      :email => "foo@example.com",
      :api => "Example API",
      :subject => "Support",
      :message => "Message body",
    }

    response = make_request(params.merge({
      :api => "foo",
    }))
    assert_response_code(200, response)

    response = make_request(params.merge({
      :api => "FOO",
    }))
    assert_response_code(200, response)

    override_config({
      "web" => {
        "contact" => {
          "api_exclude_regex" => "oo",
        },
      },
    }) do
      response = make_request(params.merge({
        :api => "foo",
      }))
      assert_response_code(422, response)
      data = MultiJson.load(response.body)
      assert_equal({
        "errors" => [{
          "code" => "INVALID_INPUT",
          "field" => "api",
          "message" => "is invalid",
          "full_message" => "API: is invalid",
        }],
      }, data)

      response = make_request(params.merge({
        :api => "FOO",
      }))
      assert_response_code(422, response)
      data = MultiJson.load(response.body)
      assert_equal({
        "errors" => [{
          "code" => "INVALID_INPUT",
          "field" => "api",
          "message" => "is invalid",
          "full_message" => "API: is invalid",
        }],
      }, data)
    end
  end

  def test_subject_format
    response = make_request({
      :name => "Foo",
      :email => "foo@example.com",
      :api => "Example API",
      :subject => "<script",
      :message => "Message body",
    })
    assert_response_code(422, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)
    assert_equal([
      {
        "code" => "INVALID_INPUT",
        "message" => "is invalid",
        "field" => "subject",
        "full_message" => "Subject: is invalid",
      },
    ], data["errors"])
  end

  def test_subject_format_configurable
    params = {
      :name => "Foo",
      :email => "foo@example.com",
      :api => "Example API",
      :subject => "Support",
      :message => "Message body",
    }

    response = make_request(params.merge({
      :subject => "foo",
    }))
    assert_response_code(200, response)

    response = make_request(params.merge({
      :subject => "FOO",
    }))
    assert_response_code(200, response)

    override_config({
      "web" => {
        "contact" => {
          "subject_exclude_regex" => "oo",
        },
      },
    }) do
      response = make_request(params.merge({
        :subject => "foo",
      }))
      assert_response_code(422, response)
      data = MultiJson.load(response.body)
      assert_equal({
        "errors" => [{
          "code" => "INVALID_INPUT",
          "field" => "subject",
          "message" => "is invalid",
          "full_message" => "Subject: is invalid",
        }],
      }, data)

      response = make_request(params.merge({
        :subject => "FOO",
      }))
      assert_response_code(422, response)
      data = MultiJson.load(response.body)
      assert_equal({
        "errors" => [{
          "code" => "INVALID_INPUT",
          "field" => "subject",
          "message" => "is invalid",
          "full_message" => "Subject: is invalid",
        }],
      }, data)
    end
  end

  def test_message_format
    response = make_request({
      :name => "Foo",
      :email => "foo@example.com",
      :api => "Example API",
      :subject => "Support",
      :message => "123",
    })
    assert_response_code(422, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)
    assert_equal([
      {
        "code" => "INVALID_INPUT",
        "message" => "is invalid",
        "field" => "message",
        "full_message" => "Message: is invalid",
      },
    ], data["errors"])

    response = make_request({
      :name => "Foo",
      :email => "foo@example.com",
      :api => "Example API",
      :subject => "Support",
      :message => " 123 ",
    })
    assert_response_code(422, response)
    data = MultiJson.load(response.body)
    assert_equal(["errors"], data.keys)
    assert_equal([
      {
        "code" => "INVALID_INPUT",
        "message" => "is invalid",
        "field" => "message",
        "full_message" => "Message: is invalid",
      },
    ], data["errors"])

    response = make_request({
      :name => "Foo",
      :email => "foo@example.com",
      :api => "Example API",
      :subject => "Support",
      :message => "Numbers inside message:\n123\nTest",
    })
    assert_response_code(200, response)
  end

  def test_message_format_configurable
    params = {
      :name => "Foo",
      :email => "foo@example.com",
      :api => "Example API",
      :subject => "Support",
      :message => "Message body",
    }

    response = make_request(params.merge({
      :message => "foo",
    }))
    assert_response_code(200, response)

    response = make_request(params.merge({
      :message => "FOO",
    }))
    assert_response_code(200, response)

    override_config({
      "web" => {
        "contact" => {
          "message_exclude_regex" => "oo",
        },
      },
    }) do
      response = make_request(params.merge({
        :message => "foo",
      }))
      assert_response_code(422, response)
      data = MultiJson.load(response.body)
      assert_equal({
        "errors" => [{
          "code" => "INVALID_INPUT",
          "field" => "message",
          "message" => "is invalid",
          "full_message" => "Message: is invalid",
        }],
      }, data)

      response = make_request(params.merge({
        :message => "FOO",
      }))
      assert_response_code(422, response)
      data = MultiJson.load(response.body)
      assert_equal({
        "errors" => [{
          "code" => "INVALID_INPUT",
          "field" => "message",
          "message" => "is invalid",
          "full_message" => "Message: is invalid",
        }],
      }, data)
    end
  end

  private

  def make_request(attributes)
    user = FactoryBot.create(:api_user, {
      :roles => ["api-umbrella-contact-form"],
    })

    Typhoeus.post("https://127.0.0.1:9081/api-umbrella/v1/contact.json", http_options.deep_merge({
      :headers => {
        "X-Api-Key" => user.api_key,
        "Content-Type" => "application/x-www-form-urlencoded",
      },
      :body => {
        :contact => attributes,
      },
    }))
  end
end
