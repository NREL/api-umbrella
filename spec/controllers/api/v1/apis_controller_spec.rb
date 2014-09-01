require 'spec_helper'

describe Api::V1::ApisController do
  before(:all) do
    @admin = FactoryGirl.create(:admin)
    @google_admin = FactoryGirl.create(:limited_admin, :groups => [FactoryGirl.create(:google_admin_group, :backend_manage_access)])
    @unauthorized_admin = FactoryGirl.create(:limited_admin, :groups => [FactoryGirl.create(:google_admin_group, :backend_publish_access)])

    @api = FactoryGirl.create(:api)
    @google_api = FactoryGirl.create(:google_api)
    @google_extra_url_match_api = FactoryGirl.create(:google_extra_url_match_api)
    @yahoo_api = FactoryGirl.create(:yahoo_api)
  end

  describe "GET index" do
    it "returns datatables output fields" do
      admin_token_auth(@admin)
      get :index, :format => "json"

      data = MultiJson.load(response.body)
      data.keys.sort.should eql([
        "data",
        "draw",
        "recordsFiltered",
        "recordsTotal",
      ])
    end

    describe "admin permissions" do
      it "includes all apis for superuser admins" do
        admin_token_auth(@admin)
        get :index, :format => "json"

        data = MultiJson.load(response.body)
        api_ids = data["data"].map { |api| api["id"] }
        api_ids.should include(@api.id)
        api_ids.should include(@google_api.id)
        api_ids.should include(@google_extra_url_match_api.id)
        api_ids.should include(@yahoo_api.id)
      end

      it "includes apis the admin has access to" do
        admin_token_auth(@google_admin)
        get :index, :format => "json"

        data = MultiJson.load(response.body)
        api_ids = data["data"].map { |api| api["id"] }
        api_ids.should include(@google_api.id)
      end

      it "excludes apis the admin does not have access to" do
        admin_token_auth(@google_admin)
        get :index, :format => "json"

        data = MultiJson.load(response.body)
        api_ids = data["data"].map { |api| api["id"] }
        api_ids.should_not include(@yahoo_api.id)
      end

      it "excludes apis the admin only has partial access to" do
        admin_token_auth(@google_admin)
        get :index, :format => "json"

        data = MultiJson.load(response.body)
        api_ids = data["data"].map { |api| api["id"] }
        api_ids.should_not include(@google_extra_url_match_api.id)
      end

      it "excludes all apis for admins without proper access" do
        admin_token_auth(@unauthorized_admin)
        get :index, :format => "json"

        data = MultiJson.load(response.body)
        data["data"].length.should eql(0)
      end
    end
  end

  describe "GET show" do
    describe "admin permissions" do
      it "allows superuser admins to view any api" do
        admin_token_auth(@admin)
        get :show, :format => "json", :id => @api.id

        response.status.should eql(200)
        data = MultiJson.load(response.body)
        data["api"]["id"].should eql(@api.id)
      end

      it "allows admins to create apis within the scope it has access to" do
        admin_token_auth(@google_admin)
        get :show, :format => "json", :id => @google_api.id

        response.status.should eql(200)
        data = MultiJson.load(response.body)
        data["api"]["id"].should eql(@google_api.id)
      end

      it "prevents admins from creating apis outside the scope it has access to" do
        admin_token_auth(@google_admin)
        get :show, :format => "json", :id => @google_extra_url_match_api.id

        response.status.should eql(403)
        data = MultiJson.load(response.body)
        data.keys.should eql(["errors"])
      end

      it "forbids admins without proper access" do
        admin_token_auth(@unauthorized_admin)
        get :show, :format => "json", :id => @google_api.id

        response.status.should eql(403)
        data = MultiJson.load(response.body)
        data.keys.should eql(["errors"])
      end
    end
  end

  describe "POST create" do
    describe "admin permissions" do
      it "allows superuser admins to create any api" do
        admin_token_auth(@admin)
        attributes = FactoryGirl.attributes_for(:api)

        expect do
          post :create, :format => "json", :api => attributes
          response.status.should eql(201)
          data = MultiJson.load(response.body)
          data["api"]["name"].should eql(attributes[:name])
        end.to change { Api.count }.by(1)
      end

      it "allows admins to create apis within the scope it has access to" do
        admin_token_auth(@google_admin)
        attributes = FactoryGirl.attributes_for(:google_api)

        expect do
          post :create, :format => "json", :api => attributes
          response.status.should eql(201)
          data = MultiJson.load(response.body)
          data["api"]["name"].should eql(attributes[:name])
        end.to change { Api.count }.by(1)
      end

      it "prevents admins from creating apis outside the scope it has access to" do
        admin_token_auth(@google_admin)
        attributes = FactoryGirl.attributes_for(:google_extra_url_match_api)

        expect do
          post :create, :format => "json", :api => attributes
          response.status.should eql(403)
          data = MultiJson.load(response.body)
          data.keys.should eql(["errors"])
        end.to_not change { Api.count }
      end

      it "forbids admins without proper access" do
        admin_token_auth(@unauthorized_admin)
        attributes = FactoryGirl.attributes_for(:google_api)

        expect do
          post :create, :format => "json", :api => attributes
          response.status.should eql(403)
          data = MultiJson.load(response.body)
          data.keys.should eql(["errors"])
        end.to_not change { Api.count }
      end
    end
  end

  describe "PUT update" do
    describe "admin permissions" do
      it "allows superuser admins to update any api" do
        admin_token_auth(@admin)
        attributes = @api.serializable_hash
        attributes["name"] = "Example Updated #{rand(999_999)}"
        put :update, :format => "json", :id => @api.id, :api => attributes

        response.status.should eql(204)
        @api = Api.find(@api.id)
        @api.name.should eql(attributes["name"])
      end

      it "allows admins to update apis within the scope it has access to" do
        admin_token_auth(@google_admin)
        attributes = @google_api.serializable_hash
        attributes["name"] = "Google Updated #{rand(999_999)}"
        put :update, :format => "json", :id => @google_api.id, :api => attributes

        response.status.should eql(204)
        @google_api = Api.find(@google_api.id)
        @google_api.name.should eql(attributes["name"])
      end

      it "prevents admins from updating apis outside the scope it has access to" do
        admin_token_auth(@google_admin)
        attributes = @google_extra_url_match_api.serializable_hash
        attributes["name"] = "Google Updated #{rand(999_999)}"
        put :update, :format => "json", :id => @google_extra_url_match_api.id, :api => attributes

        response.status.should eql(403)
        data = MultiJson.load(response.body)
        data.keys.should eql(["errors"])
        @google_extra_url_match_api = Api.find(@google_extra_url_match_api.id)
        @google_extra_url_match_api.name.should_not eql(attributes["name"])
      end

      it "prevents admins from updating apis within its scope to contain routing outside its scope" do
        admin_token_auth(@google_admin)
        attributes = @google_api.serializable_hash
        attributes["name"] = "Google Updated #{rand(999_999)}"
        attributes["url_matches"] << FactoryGirl.attributes_for(:api_url_match, :frontend_prefix => "/foo", :backend_prefix => "/")
        put :update, :format => "json", :id => @google_api.id, :api => attributes

        response.status.should eql(403)
        data = MultiJson.load(response.body)
        data.keys.should eql(["errors"])
        @google_api = Api.find(@google_api.id)
        @google_api.name.should_not eql(attributes["name"])
        @google_api.url_matches.length.should eql(1)
      end

      it "forbids admins without proper access" do
        admin_token_auth(@unauthorized_admin)
        attributes = @google_api.serializable_hash
        attributes["name"] = "Google Updated #{rand(999_999)}"
        put :update, :format => "json", :id => @google_api.id, :api => attributes

        response.status.should eql(403)
        data = MultiJson.load(response.body)
        data.keys.should eql(["errors"])
        @google_extra_url_match_api = Api.find(@google_extra_url_match_api.id)
        @google_extra_url_match_api.name.should_not eql(attributes["name"])
      end
    end
  end

  describe "DELETE destroy" do
    it "performs soft-deletes" do
      admin_token_auth(@admin)
      api = FactoryGirl.create(:api)

      delete :destroy, :format => "json", :id => api.id

      Api.where(:id => api.id).first.should eql(nil)
      Api.deleted.where(:id => api.id).first.should be_kind_of(Api)
    end

    describe "admin permissions" do
      it "allows superuser admins to delete any api" do
        admin_token_auth(@admin)
        api = FactoryGirl.create(:api)

        expect do
          delete :destroy, :format => "json", :id => api.id
          response.status.should eql(204)
        end.to change { Api.count }.by(-1)
      end

      it "allows admins to delete apis within the scope it has access to" do
        admin_token_auth(@google_admin)
        api = FactoryGirl.create(:google_api)

        expect do
          delete :destroy, :format => "json", :id => api.id
          response.status.should eql(204)
        end.to change { Api.count }.by(-1)
      end

      it "prevents admins from deleting apis outside the scope it has access to" do
        admin_token_auth(@google_admin)
        api = FactoryGirl.create(:google_extra_url_match_api)

        expect do
          delete :destroy, :format => "json", :id => api.id
          response.status.should eql(403)
          data = MultiJson.load(response.body)
          data.keys.should eql(["errors"])
        end.to_not change { Api.count }
      end

      it "forbids admins without proper access" do
        admin_token_auth(@unauthorized_admin)
        api = FactoryGirl.create(:google_api)

        expect do
          delete :destroy, :format => "json", :id => api.id
          response.status.should eql(403)
          data = MultiJson.load(response.body)
          data.keys.should eql(["errors"])
        end.to_not change { Api.count }
      end
    end
  end
end
