require "spec_helper"

describe Api::V1::UsersController do
  before(:all) do
    @admin = FactoryGirl.create(:admin)
    @google_admin = FactoryGirl.create(:limited_admin, :groups => [FactoryGirl.create(:google_admin_group, :user_view_permission, :user_manage_permission)])

    Api.delete_all
    @api = FactoryGirl.create(:api)
    @google_api = FactoryGirl.create(:google_api)
    @google_extra_url_match_api = FactoryGirl.create(:google_extra_url_match_api)
    @yahoo_api = FactoryGirl.create(:yahoo_api)
  end

  before(:each) do
    ApiUser.where(:registration_source.ne => "seed").delete_all
  end

  shared_examples "admin token access" do |method, action|
    it "forbids access without an admin token" do
      send(method, action, params)
      response.status.should eql(401)
      data = MultiJson.load(response.body)
      data.should eql({
        "error" => "You need to sign in or sign up before continuing.",
      })
    end

    it "allows access with an admin token" do
      admin_token_auth(@admin)
      send(method, action, params)
      response.status.should eql(success_response_status)
    end
  end

  shared_examples "no api key role access" do |method, action|
    it "forbids access with an api key" do
      request.env["HTTP_X_API_ROLES"] = "api-umbrella-key-creator"
      send(method, action, params)
      response.status.should eql(401)
      data = MultiJson.load(response.body)
      data.should eql({
        "error" => "You need to sign in or sign up before continuing.",
      })
    end
  end

  shared_examples "api key role access" do |method, action|
    it "forbids access without the special role" do
      request.env["HTTP_X_API_ROLES"] = "api-umbrella-key-creator-bogus"
      send(method, action, params)
      response.status.should eql(401)
      data = MultiJson.load(response.body)
      data.should eql({
        "error" => "You need to sign in or sign up before continuing.",
      })
    end

    it "allows access with a special role" do
      request.env["HTTP_X_API_ROLES"] = "test1,api-umbrella-key-creator,test2"
      send(method, action, params)
      response.status.should eql(success_response_status)
    end
  end

  shared_examples "admin role permissions" do |method, action|
    it "allows superuser admins to assign any roles" do
      existing_roles = ApiUserRole.all
      existing_roles.should include("google-write")
      existing_roles.should include("yahoo-write")
      existing_roles.should_not include("new-write")

      admin_token_auth(@admin)
      attributes = FactoryGirl.attributes_for(:api_user, {
        :roles => [
          "google-write",
          "yahoo-write",
          "new-write",
        ],
      })

      expect do
        send(method, action, params.merge(:user => attributes))
        response.status.should eql(success_response_status)
        data = MultiJson.load(response.body)
        user = ApiUser.find(data["user"]["id"])
        user.roles.should eql(attributes[:roles])
      end.to change { ApiUser.count }.by(success_record_change_count)
    end

    it "allows limited admins to assign any unused role" do
      admin_token_auth(@google_admin)
      attributes = FactoryGirl.attributes_for(:api_user, {
        :roles => [
          "new-role#{rand(999_999)}",
        ],
      })

      expect do
        send(method, action, params.merge(:user => attributes))
        response.status.should eql(success_response_status)
        data = MultiJson.load(response.body)
        user = ApiUser.find(data["user"]["id"])
        user.roles.should eql(attributes[:roles])
      end.to change { ApiUser.count }.by(success_record_change_count)
    end

    it "allows limited admins to assign an existing role that exists within its scope" do
      existing_roles = ApiUserRole.all
      existing_roles.should include("google-write")

      admin_token_auth(@google_admin)
      attributes = FactoryGirl.attributes_for(:api_user, {
        :roles => [
          "google-write",
        ],
      })

      expect do
        send(method, action, params.merge(:user => attributes))
        response.status.should eql(success_response_status)
        data = MultiJson.load(response.body)
        user = ApiUser.find(data["user"]["id"])
        user.roles.should eql(attributes[:roles])
      end.to change { ApiUser.count }.by(success_record_change_count)
    end

    it "forbids limited admins from assigning an existing role that exists outside its scope at the settings level" do
      existing_roles = ApiUserRole.all
      existing_roles.should include("yahoo-write")

      admin_token_auth(@google_admin)
      attributes = FactoryGirl.attributes_for(:api_user, {
        :roles => [
          "yahoo-write",
        ],
      })

      expect do
        send(method, action, params.merge(:user => attributes))
        response.status.should eql(403)
        data = MultiJson.load(response.body)
        data.keys.should eql(["errors"])
      end.to_not change { ApiUser.count }
    end

    it "forbids limited admins from assigning an existing role that exists in an api the admin only has partial access to" do
      existing_roles = ApiUserRole.all
      existing_roles.should include("google-extra-write")

      admin_token_auth(@google_admin)
      attributes = FactoryGirl.attributes_for(:api_user, {
        :roles => [
          "google-extra-write",
        ],
      })

      expect do
        send(method, action, params.merge(:user => attributes))
        response.status.should eql(403)
        data = MultiJson.load(response.body)
        data.keys.should eql(["errors"])
      end.to_not change { ApiUser.count }
    end

    it "allows limited admins to assign the 'api-umbrella-key-creator' role" do
      admin_token_auth(@google_admin)
      attributes = FactoryGirl.attributes_for(:api_user, {
        :roles => [
          "api-umbrella-key-creator",
        ],
      })

      expect do
        send(method, action, params.merge(:user => attributes))
        response.status.should eql(success_response_status)
        data = MultiJson.load(response.body)
        user = ApiUser.find(data["user"]["id"])
        user.roles.should eql(attributes[:roles])
      end.to change { ApiUser.count }.by(success_record_change_count)
    end

    it "forbids limited admins from assigning other new roles beginning with 'api-umbrella'" do
      admin_token_auth(@google_admin)
      attributes = FactoryGirl.attributes_for(:api_user, {
        :roles => [
          "api-umbrella#{rand(999_999)}",
        ],
      })

      expect do
        send(method, action, params.merge(:user => attributes))
        response.status.should eql(403)
        data = MultiJson.load(response.body)
        data.keys.should eql(["errors"])
      end.to_not change { ApiUser.count }
    end

    it "allows superuser admins to assign other new roles beginning with 'api-umbrella'" do
      admin_token_auth(@admin)
      attributes = FactoryGirl.attributes_for(:api_user, {
        :roles => [
          "api-umbrella#{rand(999_999)}",
        ],
      })

      expect do
        send(method, action, params.merge(:user => attributes))
        response.status.should eql(success_response_status)
        data = MultiJson.load(response.body)
        user = ApiUser.find(data["user"]["id"])
        user.roles.should eql(attributes[:roles])
      end.to change { ApiUser.count }.by(success_record_change_count)
    end
  end

  describe "GET index" do
    it "paginates results" do
      FactoryGirl.create_list(:api_user, 10)

      user_count = ApiUser.count
      user_count.should be >= 10

      admin_token_auth(@admin)
      get :index, :format => "json", :length => 2

      data = MultiJson.load(response.body)
      data["recordsTotal"].should eql(user_count)
      data["recordsFiltered"].should eql(user_count)
      data["data"].length.should eql(2)
    end

    it "only returns the api key preview and not the full api key" do
      api_user = FactoryGirl.create(:api_user)

      admin_token_auth(@admin)
      get(:index, :format => "json")
      response.status.should eql(200)

      data = MultiJson.load(response.body)
      user = data["data"].find { |u| u["id"] == api_user.id }
      user.keys.should_not include("api_key")
      user.keys.should_not include("api_key_hides_at")
      user["api_key_preview"].should eql("#{api_user.api_key[0, 6]}...")
    end

    describe "search" do
      it "searches through first names as wildcard, case-insensitive" do
        api_user = FactoryGirl.create(:api_user, :first_name => "FirstNameSearchTest")

        admin_token_auth(@admin)
        get(:index, :format => "json", :search => { :value => "IRSTNAMEsearchT" })
        response.status.should eql(200)

        data = MultiJson.load(response.body)
        data["recordsTotal"].should eql(1)
        data["data"].first["id"].should eql(api_user.id)
      end

      it "searches through last names as wildcard, case-insensitive" do
        api_user = FactoryGirl.create(:api_user, :last_name => "LastNameSearchTest")

        admin_token_auth(@admin)
        get(:index, :format => "json", :search => { :value => "astnamesearcht" })
        response.status.should eql(200)

        data = MultiJson.load(response.body)
        data["recordsTotal"].should eql(1)
        data["data"].first["id"].should eql(api_user.id)
      end

      it "searches through emails as wildcard, case-insensitive" do
        api_user = FactoryGirl.create(:api_user, :email => "EmailSearchTest@example.com")

        admin_token_auth(@admin)
        get(:index, :format => "json", :search => { :value => "mailsearchtest@example" })
        response.status.should eql(200)

        data = MultiJson.load(response.body)
        data["recordsTotal"].should eql(1)
        data["data"].first["id"].should eql(api_user.id)
      end

      it "searches through api keys as wildcard, case-insensitive" do
        api_user = FactoryGirl.create(:api_user, :api_key => "API_KEY_SEARCH_TEST")

        admin_token_auth(@admin)
        get(:index, :format => "json", :search => { :value => "_key_search_tes" })
        response.status.should eql(200)

        data = MultiJson.load(response.body)
        data["recordsTotal"].should eql(1)
        data["data"].first["id"].should eql(api_user.id)
      end

      it "searches through registration sources as wildcard, case-insensitive" do
        api_user = FactoryGirl.create(:api_user, :registration_source => "RegistrationSourceSearchTest")

        admin_token_auth(@admin)
        get(:index, :format => "json", :search => { :value => "registrationsourcesearchtest" })
        response.status.should eql(200)

        data = MultiJson.load(response.body)
        data["recordsTotal"].should eql(1)
        data["data"].first["id"].should eql(api_user.id)
      end

      it "searches through roles as wildcard, case-insensitive" do
        api_user = FactoryGirl.create(:api_user, :roles => ["RoleSearchTest1", "RoleSearchTest2", "RoleSearchTest3"])

        admin_token_auth(@admin)
        get(:index, :format => "json", :search => { :value => "olesearchtest3" })
        response.status.should eql(200)

        data = MultiJson.load(response.body)
        data["recordsTotal"].should eql(1)
        data["data"].first["id"].should eql(api_user.id)
      end

      it "searches through ids as wildcard, case-insensitive" do
        api_user = FactoryGirl.create(:api_user, :id => "381f2ad2-493b-4750-994d-a046fa6eae70")

        admin_token_auth(@admin)
        get(:index, :format => "json", :search => { :value => "994D-A046" })
        response.status.should eql(200)

        data = MultiJson.load(response.body)
        data["recordsTotal"].should eql(1)
        data["data"].first["id"].should eql(api_user.id)
      end
    end
  end

  describe "GET show" do
    before(:each) do
      @api_user = FactoryGirl.create(:api_user, :created_by => @admin.id)
    end

    shared_examples "allowed to view full api key" do
      it "returns api key preview, the full api key, and a hides at date" do
        get(:show, :id => api_user.id, :format => "json")
        response.status.should eql(200)

        data = MultiJson.load(response.body)
        data["user"]["api_key"].should eql(api_user.api_key)
        data["user"]["api_key_hides_at"].should eql((api_user.created_at + 2.weeks).iso8601)
        data["user"]["api_key_preview"].should eql("#{api_user.api_key[0, 6]}...")
      end
    end

    shared_examples "not allowed to view full api key" do
      it "returns only the api key preview, but not the full api key or hides at date" do
        get(:show, :id => api_user.id, :format => "json")
        response.status.should eql(200)

        data = MultiJson.load(response.body)
        data["user"].keys.should_not include("api_key")
        data["user"].keys.should_not include("api_key_hides_at")
        data["user"]["api_key_preview"].should eql("#{api_user.api_key[0, 6]}...")
      end
    end

    let(:params) do
      { :format => "json", :id => @api_user.id }
    end
    let(:success_response_status) { 200 }

    it_behaves_like "admin token access", :get, :show
    it_behaves_like "no api key role access", :get, :show

    it "contains the user response" do
      admin_token_auth(@admin)
      get :show, params

      data = MultiJson.load(response.body)
      data.keys.sort.should eql([
        "user",
      ])

      expected_keys = [
        "api_key",
        "api_key_hides_at",
        "api_key_preview",
        "created_at",
        "creator",
        "email",
        "email_verified",
        "enabled",
        "first_name",
        "id",
        "last_name",
        "registration_ip",
        "registration_origin",
        "registration_referer",
        "registration_source",
        "registration_user_agent",
        "roles",
        "settings",
        "throttle_by_ip",
        "updated_at",
        "updater",
        "use_description",
      ]

      if(ApiUser.fields.include?("website"))
        expected_keys << "website"
      end

      data["user"].keys.sort.should eql(expected_keys.sort)
    end

    describe "rate limits" do
      it "returns embedded custom limit objects" do
        user = FactoryGirl.create(:custom_rate_limit_api_user)

        admin_token_auth(@admin)
        get :show, :format => "json", :id => user.id

        response.status.should eql(200)
        data = MultiJson.load(response.body)
        data["user"]["settings"]["rate_limits"].length.should eql(1)
        rate_limit = data["user"]["settings"]["rate_limits"].first
        rate_limit.keys.sort.should eql([
          "id",
          # Legacy _id field we never meant to return (everything else returns
          # just "id"), but we accidentally did in this embedded case. Keep
          # returning for backwards compatibility, but should remove for V2 of
          # APIs.
          "_id",
          "accuracy",
          "distributed",
          "duration",
          "limit",
          "limit_by",
          "response_headers",
        ].sort)
        rate_limit["id"].should be_a_uuid
        rate_limit["_id"].should eql(rate_limit["id"])
        rate_limit["accuracy"].should eql(5000)
        rate_limit["distributed"].should eql(true)
        rate_limit["duration"].should eql(60000)
        rate_limit["limit"].should eql(500)
        rate_limit["limit_by"].should eql("ip")
        rate_limit["response_headers"].should eql(true)
      end
    end

    describe "api key" do
      describe "superuser admin is logged in" do
        let(:current_admin) { FactoryGirl.create(:admin) }
        login_admin

        describe "accounts without roles" do
          describe "new accounts they created" do
            let(:api_user) { FactoryGirl.create(:api_user, :created_by => current_admin.id, :created_at => (Time.now - 2.weeks + 5.minutes), :roles => nil) }
            it_behaves_like "allowed to view full api key"
          end

          describe "old accounts they created" do
            let(:api_user) { FactoryGirl.create(:api_user, :created_by => current_admin.id, :created_at => (Time.now - 2.weeks - 5.minutes), :roles => nil) }
            it_behaves_like "allowed to view full api key"
          end

          describe "new accounts other admins created" do
            let(:api_user) { FactoryGirl.create(:api_user, :created_by => @admin.id, :created_at => Time.now - 2.weeks + 5.minutes, :roles => nil) }
            it_behaves_like "allowed to view full api key"
          end

          describe "old accounts other admins created" do
            let(:api_user) { FactoryGirl.create(:api_user, :created_by => @admin.id, :created_at => Time.now - 2.weeks - 5.minutes, :roles => nil) }
            it_behaves_like "allowed to view full api key"
          end
        end

        describe "accounts with roles" do
          describe "new accounts they created" do
            let(:api_user) { FactoryGirl.create(:api_user, :created_by => current_admin.id, :created_at => Time.now - 2.weeks + 5.minutes, :roles => ["foo"]) }
            it_behaves_like "allowed to view full api key"
          end

          describe "old accounts they created" do
            let(:api_user) { FactoryGirl.create(:api_user, :created_by => current_admin.id, :created_at => Time.now - 2.weeks - 5.minutes, :roles => ["foo"]) }
            it_behaves_like "allowed to view full api key"
          end

          describe "new accounts other admins created" do
            let(:api_user) { FactoryGirl.create(:api_user, :created_by => @admin.id, :created_at => Time.now - 2.weeks + 5.minutes, :roles => ["foo"]) }
            it_behaves_like "allowed to view full api key"
          end

          describe "old accounts other admins created" do
            let(:api_user) { FactoryGirl.create(:api_user, :created_by => @admin.id, :created_at => Time.now - 2.weeks - 5.minutes, :roles => ["foo"]) }
            it_behaves_like "allowed to view full api key"
          end
        end
      end

      describe "limited admin is logged in" do
        let(:current_admin) { FactoryGirl.create(:limited_admin) }
        login_admin

        describe "accounts without roles" do
          describe "new accounts they created" do
            let(:api_user) { FactoryGirl.create(:api_user, :created_by => current_admin.id, :created_at => (Time.now - 2.weeks + 5.minutes), :roles => nil) }
            it_behaves_like "allowed to view full api key"
          end

          describe "old accounts they created" do
            let(:api_user) { FactoryGirl.create(:api_user, :created_by => current_admin.id, :created_at => (Time.now - 2.weeks - 5.minutes), :roles => nil) }
            it_behaves_like "not allowed to view full api key"
          end

          describe "new accounts other admins created" do
            let(:api_user) { FactoryGirl.create(:api_user, :created_by => @admin.id, :created_at => Time.now - 2.weeks + 5.minutes, :roles => nil) }
            it_behaves_like "allowed to view full api key"
          end

          describe "old accounts other admins created" do
            let(:api_user) { FactoryGirl.create(:api_user, :created_by => @admin.id, :created_at => Time.now - 2.weeks - 5.minutes, :roles => nil) }
            it_behaves_like "not allowed to view full api key"
          end
        end

        describe "accounts with roles" do
          describe "new accounts they created" do
            let(:api_user) { FactoryGirl.create(:api_user, :created_by => current_admin.id, :created_at => Time.now - 2.weeks + 5.minutes, :roles => ["foo"]) }
            it_behaves_like "allowed to view full api key"
          end

          describe "old accounts they created" do
            let(:api_user) { FactoryGirl.create(:api_user, :created_by => current_admin.id, :created_at => Time.now - 2.weeks - 5.minutes, :roles => ["foo"]) }
            it_behaves_like "not allowed to view full api key"
          end

          describe "new accounts other admins created" do
            let(:api_user) { FactoryGirl.create(:api_user, :created_by => @admin.id, :created_at => Time.now - 2.weeks + 5.minutes, :roles => ["foo"]) }
            it_behaves_like "not allowed to view full api key"
          end

          describe "old accounts other admins created" do
            let(:api_user) { FactoryGirl.create(:api_user, :created_by => @admin.id, :created_at => Time.now - 2.weeks - 5.minutes, :roles => ["foo"]) }
            it_behaves_like "not allowed to view full api key"
          end
        end
      end
    end
  end

  describe "POST create" do
    let(:params) do
      {
        :format => "json",
        :user => {
          :first_name => "Mr",
          :last_name => "Potato",
          :email => "potato@example.com",
          :use_description => "",
          :terms_and_conditions => "1",
        },
      }
    end
    let(:success_response_status) { 201 }
    let(:success_record_change_count) { 1 }

    it_behaves_like "admin token access", :post, :create
    it_behaves_like "api key role access", :post, :create
    it_behaves_like "admin role permissions", :post, :create

    it "performs an create" do
      admin_token_auth(@admin)
      expect do
        post :create, params

        data = MultiJson.load(response.body)
        data["user"]["last_name"].should eql("Potato")

        user = ApiUser.find(data["user"]["id"])
        user.last_name.should eql("Potato")
      end.to change { ApiUser.count }.by(1)
    end

    it "returns a validation error if the user attributes aren't present" do
      admin_token_auth(@admin)
      expect do
        post :create, :format => "json"

        response.status.should eql(422)
        data = MultiJson.load(response.body)
        data.keys.should eql(["errors"])
      end.to_not change { ApiUser.count }
    end

    it "returns a validation error if the user attributes are an unexpected object" do
      admin_token_auth(@admin)
      expect do
        post :create, :format => "json", :user => "something"

        response.status.should eql(422)
        data = MultiJson.load(response.body)
        data.keys.should eql(["errors"])
      end.to_not change { ApiUser.count }
    end

    it "returns a wildcard CORS response" do
      admin_token_auth(@admin)
      post :create, params
      response.headers["Access-Control-Allow-Origin"].should eql("*")
    end

    it "allows admins to set private fields" do
      p = params
      p[:user][:roles] = ["admin"]

      admin_token_auth(@admin)
      post :create, p

      response.status.should eql(success_response_status)

      data = MultiJson.load(response.body)
      user = ApiUser.find(data["user"]["id"])
      user.roles.should eql(["admin"])
    end

    it "forbids non-admins from setting private fields" do
      p = params
      p[:user][:roles] = ["admin"]

      request.env["HTTP_X_API_ROLES"] = "api-umbrella-key-creator"
      post :create, p

      response.status.should eql(success_response_status)

      data = MultiJson.load(response.body)
      user = ApiUser.find(data["user"]["id"])
      user.roles.should eql(nil)
    end

    it "defaults the registration source to 'api'" do
      admin_token_auth(@admin)
      post :create, params
      data = MultiJson.load(response.body)
      data["user"]["registration_source"].should eql("api")
    end

    it "allows setting a custom registration source" do
      admin_token_auth(@admin)
      p = params
      p[:user][:registration_source] = "whatever"
      post :create, p
      data = MultiJson.load(response.body)
      data["user"]["registration_source"].should eql("whatever")
    end

    it "captures the requester's IP - does not trust x-forwarded-for from arbitrary IP" do
      admin_token_auth(@admin)
      request.env["REMOTE_ADDR"] = "48.146.218.185"
      request.env["HTTP_X_FORWARDED_FOR"] = "3.3.3.3"
      post :create, params
      data = MultiJson.load(response.body)
      user = ApiUser.find(data["user"]["id"])
      user.registration_ip.should eql("48.146.218.185")
    end

    it "captures the requester's IP - does trust x-forwarded-for from local IP" do
      admin_token_auth(@admin)
      request.env["REMOTE_ADDR"] = "127.0.0.1"
      request.env["HTTP_X_FORWARDED_FOR"] = "3.3.3.3"
      post :create, params
      data = MultiJson.load(response.body)
      user = ApiUser.find(data["user"]["id"])
      user.registration_ip.should eql("3.3.3.3")
    end

    it "captures the requester's user agent" do
      admin_token_auth(@admin)
      request.env["HTTP_USER_AGENT"] = "curl"
      post :create, params
      data = MultiJson.load(response.body)
      user = ApiUser.find(data["user"]["id"])
      user.registration_user_agent.should eql("curl")
    end

    it "captures the requester's referer" do
      admin_token_auth(@admin)
      request.env["HTTP_REFERER"] = "http://example.com/foo"
      post :create, params
      data = MultiJson.load(response.body)
      user = ApiUser.find(data["user"]["id"])
      user.registration_referer.should eql("http://example.com/foo")
    end

    it "captures the requester's origin" do
      admin_token_auth(@admin)
      request.env["HTTP_ORIGIN"] = "http://example.com"
      post :create, params
      data = MultiJson.load(response.body)
      user = ApiUser.find(data["user"]["id"])
      user.registration_origin.should eql("http://example.com")
    end

    it "returns registration requester information for admin users" do
      admin_token_auth(@admin)
      request.env["REMOTE_ADDR"] = "1.2.3.4"
      request.env["HTTP_USER_AGENT"] = "curl"
      request.env["HTTP_REFERER"] = "http://example.com/foo"
      request.env["HTTP_ORIGIN"] = "http://example.com"
      post :create, params
      data = MultiJson.load(response.body)
      data["user"]["registration_ip"].should eql("1.2.3.4")
      data["user"]["registration_user_agent"].should eql("curl")
      data["user"]["registration_referer"].should eql("http://example.com/foo")
      data["user"]["registration_origin"].should eql("http://example.com")
    end

    it "omits registration requester information for non-admin users" do
      request.env["REMOTE_ADDR"] = "1.2.3.4"
      request.env["HTTP_USER_AGENT"] = "curl"
      request.env["HTTP_REFERER"] = "http://example.com/foo"
      request.env["HTTP_ORIGIN"] = "http://example.com"
      request.env["HTTP_X_API_ROLES"] = "api-umbrella-key-creator"
      post :create, params
      data = MultiJson.load(response.body)
      data["user"]["registration_ip"].should eql(nil)
      data["user"]["registration_user_agent"].should eql(nil)
      data["user"]["registration_referer"].should eql(nil)
      data["user"]["registration_origin"].should eql(nil)
    end

    describe "e-mail verification" do
      it "returns the api key immediately and does not mark the user as e-mail verified by default" do
        request.env["HTTP_X_API_ROLES"] = "api-umbrella-key-creator"
        post :create, params
        data = MultiJson.load(response.body)
        data["user"]["api_key"].should be_kind_of(String)
        user = ApiUser.find(data["user"]["id"])
        user.email_verified.should eql(false)
      end

      it "does not return the api key and marks the user as e-mail verified when requested" do
        request.env["HTTP_X_API_ROLES"] = "api-umbrella-key-creator"
        p = params
        p[:options] = { :verify_email => true }
        post :create, p
        data = MultiJson.load(response.body)
        data["user"]["api_key"].should eql(nil)
        user = ApiUser.find(data["user"]["id"])
        user.email_verified.should eql(true)
      end

      it "always marks the user as e-mail verified when an admin creates the account" do
        admin_token_auth(@admin)
        post :create, params
        data = MultiJson.load(response.body)
        data["user"]["api_key"].should be_kind_of(String)
        user = ApiUser.find(data["user"]["id"])
        user.email_verified.should eql(true)
      end
    end

    describe "welcome e-mail" do
      before(:each) do
        Delayed::Worker.delay_jobs = false
        ActionMailer::Base.deliveries.clear
      end

      after(:each) do
        Delayed::Worker.delay_jobs = true
      end

      it "sends a welcome e-mail to be sent when requested" do
        admin_token_auth(@admin)
        expect do
          p = params
          p[:options] = { :send_welcome_email => true }
          post :create, p
        end.to change { ActionMailer::Base.deliveries.count }.by(1)
      end

      it "does not send welcome e-mails when explicitly disabled" do
        admin_token_auth(@admin)
        expect do
          p = params
          p[:options] = { :send_welcome_email => false }
          post :create, p
        end.to change { ActionMailer::Base.deliveries.count }.by(0)
      end

      it "does not send a welcome e-mail when the option is an unknown value" do
        admin_token_auth(@admin)
        expect do
          p = params
          p[:options] = { :send_welcome_email => 1 }
          post :create, p
        end.to change { ActionMailer::Base.deliveries.count }.by(0)
      end

      it "does not send welcome e-mails by default" do
        admin_token_auth(@admin)
        expect do
          post :create, params
        end.to change { ActionMailer::Base.deliveries.count }.by(0)
      end

      it "sends welcome e-mails when the user-based 'send_welcome_email' attribute is set to anything (for the admin tool/backwards compatibility)" do
        admin_token_auth(@admin)
        expect do
          p = params
          p[:user][:send_welcome_email] = "0"
          post :create, p
        end.to change { ActionMailer::Base.deliveries.count }.by(1)
      end

      it "queues a welcome e-mail to when delayed job is enabled" do
        Delayed::Worker.delay_jobs = true
        admin_token_auth(@admin)
        expect do
          expect do
            p = params
            p[:options] = { :send_welcome_email => true }
            post :create, p
          end.to change { Delayed::Job.count }.by(1)
        end.to change { ActionMailer::Base.deliveries.count }.by(0)
      end

      it "sends the e-mail to the user that signed up" do
        admin_token_auth(@admin)
        p = params
        p[:options] = { :send_welcome_email => true }
        post :create, p
        ActionMailer::Base.deliveries.first.to.should eql(["potato@example.com"])
      end

      it "includes the API key in the signup message" do
        admin_token_auth(@admin)
        p = params
        p[:options] = { :send_welcome_email => true }
        post :create, p

        data = MultiJson.load(response.body)
        user = ApiUser.find(data["user"]["id"])

        ActionMailer::Base.deliveries.first.encoded.should include(user.api_key)
      end

      describe "e-mail subject" do
        it "defaults to the configured site name" do
          admin_token_auth(@admin)
          p = params
          p[:options] = { :send_welcome_email => true }
          post :create, p
          ActionMailer::Base.deliveries.first.subject.should eql("Your API Umbrella API key")
        end

        it "changes the e-mail subject based on the site name" do
          admin_token_auth(@admin)
          p = params
          p[:options] = { :send_welcome_email => true, :site_name => "External Example" }
          post :create, p
          ActionMailer::Base.deliveries.first.subject.should eql("Your External Example API key")
        end
      end

      describe "from" do
        it "defaults to using the configured host" do
          admin_token_auth(@admin)
          p = params
          p[:options] = { :send_welcome_email => true }
          post :create, p
          ActionMailer::Base.deliveries.first.from.should eql(["noreply@localhost"])
          ActionMailer::Base.deliveries.first[:from].value.should eql("noreply@localhost")
        end

        it "allows changing the from e-mail name" do
          admin_token_auth(@admin)
          p = params
          p[:options] = { :send_welcome_email => true, :email_from_name => "Tester" }
          post :create, p
          ActionMailer::Base.deliveries.first.from.should eql(["noreply@localhost"])
          ActionMailer::Base.deliveries.first[:from].value.should eql("Tester <noreply@localhost>")
        end

        it "allows changing the from e-mail address" do
          admin_token_auth(@admin)
          p = params
          p[:options] = { :send_welcome_email => true, :email_from_address => "test@google.com" }
          post :create, p
          ActionMailer::Base.deliveries.first.from.should eql(["test@google.com"])
          ActionMailer::Base.deliveries.first[:from].value.should eql("test@google.com")
        end

        it "allows changing the both the from e-mail address and name" do
          admin_token_auth(@admin)
          p = params
          p[:options] = { :send_welcome_email => true, :email_from_name => "Tester", :email_from_address => "test@google.com" }
          post :create, p
          ActionMailer::Base.deliveries.first.from.should eql(["test@google.com"])
          ActionMailer::Base.deliveries.first[:from].value.should eql("Tester <test@google.com>")
        end
      end

      describe "example API url" do
        it "defaults to no example URL" do
          admin_token_auth(@admin)
          p = params
          p[:options] = { :send_welcome_email => true }
          post :create, p
          ActionMailer::Base.deliveries.first.encoded.should_not include("Here's an example")
        end

        it "includes an example API url when given" do
          admin_token_auth(@admin)
          p = params
          p[:options] = { :send_welcome_email => true, :example_api_url => "https://example.com/api.json?api_key={{api_key}}&test=1" }
          post :create, p
          ActionMailer::Base.deliveries.first.encoded.should include("Here's an example")
        end

        it "formats the example URL by substituting the api key" do
          admin_token_auth(@admin)
          p = params
          p[:options] = { :send_welcome_email => true, :example_api_url => "https://example.com/api.json?api_key={{api_key}}&test=1" }
          post :create, p

          data = MultiJson.load(response.body)
          user = ApiUser.find(data["user"]["id"])

          ActionMailer::Base.deliveries.first.encoded.should include(%(<a href="https://example.com/api.json?api_key=#{user.api_key}&amp;test=1">https://example.com/api.json?<strong>api_key=#{user.api_key}</strong>&amp;test=1</a>))
        end

        it "offers a plain text version" do
          admin_token_auth(@admin)
          p = params
          p[:options] = { :send_welcome_email => true, :example_api_url => "https://example.com/api.json?api_key={{api_key}}" }
          post :create, p

          data = MultiJson.load(response.body)
          user = ApiUser.find(data["user"]["id"])

          ActionMailer::Base.deliveries.first.encoded.should include("https://example.com/api.json?api_key=#{user.api_key}\r\n( https://example.com/api.json?api_key=#{user.api_key} )")
        end
      end

      describe "contact URL" do
        it "defaults to no example URL" do
          admin_token_auth(@admin)
          p = params
          p[:options] = { :send_welcome_email => true }
          post :create, p
          ActionMailer::Base.deliveries.first.encoded.should include(%(<a href="http://localhost/contact/">contact us</a>))
        end

        it "includes an example API url when given" do
          admin_token_auth(@admin)
          p = params
          p[:options] = { :send_welcome_email => true, :contact_url => "https://example.com/contact-us" }
          post :create, p
          ActionMailer::Base.deliveries.first.encoded.should include(%(<a href="https://example.com/contact-us">contact us</a>))
        end

        it "offers a plain text version" do
          admin_token_auth(@admin)
          p = params
          p[:options] = { :send_welcome_email => true }
          post :create, p
          ActionMailer::Base.deliveries.first.encoded.should include("contact us ( http://localhost/contact/ )")
        end
      end
    end
  end

  describe "PUT update" do
    before(:each) do
      @api_user = FactoryGirl.create(:api_user)
    end

    let(:params) do
      {
        :format => "json",
        :id => @api_user.id,
        :user => {
          :first_name => "Bob",
        },
      }
    end
    let(:success_response_status) { 200 }
    let(:success_record_change_count) { 0 }

    it_behaves_like "admin token access", :put, :update
    it_behaves_like "no api key role access", :put, :update
    it_behaves_like "admin role permissions", :put, :update

    it "performs an update" do
      admin_token_auth(@admin)
      put :update, params
      data = MultiJson.load(response.body)
      data["user"]["first_name"].should eql("Bob")

      user = ApiUser.find(@api_user.id)
      user.first_name.should eql("Bob")
    end

    it "leaves existing registration sources alone" do
      user = FactoryGirl.create(:api_user, :registration_source => "something")
      admin_token_auth(@admin)
      put :update, params.merge(:id => user.id)
      data = MultiJson.load(response.body)
      data["user"]["registration_source"].should eql("something")
    end
  end
end
