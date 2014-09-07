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

    it "forbids limited admins from assigning a new role beginning with 'api-umbrella'" do
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

    it "allows superuser admins to assign a new role beginning with 'api-umbrella'" do
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

  describe "GET show" do
    before(:each) do
      @api_user = FactoryGirl.create(:api_user)
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
        "api_key_preview",
        "created_at",
        "creator",
        "email",
        "enabled",
        "first_name",
        "id",
        "last_name",
        "registration_source",
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

    it "queues a welcome e-mail to be sent when requested" do
      admin_token_auth(@admin)
      expect do
        p = params
        p[:user][:send_welcome_email] = "1"
        post :create, p
      end.to change { Delayed::Job.count }.by(1)
    end

    it "does not send welcome e-mails by default" do
      admin_token_auth(@admin)
      expect do
        post :create, params
      end.to change { Delayed::Job.count }.by(0)
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
