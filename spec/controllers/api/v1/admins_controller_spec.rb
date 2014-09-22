require 'spec_helper'

describe Api::V1::AdminsController do
  before(:all) do
    Admin.delete_all

    google_api_scope = FactoryGirl.create(:google_api_scope)
    google2_api_scope = FactoryGirl.create(:google_api_scope, :host => "example.com")
    yahoo_api_scope = FactoryGirl.create(:yahoo_api_scope)

    @admin = FactoryGirl.create(:admin, :id => "admin#{rand(999_999)}")
    @superuser_with_groups_admin = FactoryGirl.create(:admin, {
      :id => "superuser_with_groups_admin#{rand(999_999)}",
      :group_ids => [
        FactoryGirl.create(:admin_group, :admin_manage_permission, :api_scopes => [
          google_api_scope,
        ]).id,
      ],
    })
    @google_admin = FactoryGirl.create(:limited_admin, {
      :id => "google_admin#{rand(999_999)}",
      :group_ids => [
        FactoryGirl.create(:admin_group, :admin_manage_permission, :api_scopes => [
          google_api_scope,
          google2_api_scope,
        ]).id,
      ],
    })
    @google_single_scope_admin = FactoryGirl.create(:limited_admin, {
      :id => "google_single_scope_admin#{rand(999_999)}",
      :group_ids => [
        FactoryGirl.create(:admin_group, :admin_manage_permission, :api_scopes => [
          google_api_scope,
        ]).id,
      ],
    })
    @unauthorized_google_admin = FactoryGirl.create(:limited_admin, {
      :id => "unauthorized_google_admin#{rand(999_999)}",
      :group_ids => [
        FactoryGirl.create(:admin_group, :user_manage_permission, :api_scopes => [
          google_api_scope,
        ]).id,
      ],
    })
    @yahoo_admin = FactoryGirl.create(:limited_admin, {
      :id => "yahoo_admin#{rand(999_999)}",
      :group_ids => [
        FactoryGirl.create(:admin_group, :api_scopes => [
          yahoo_api_scope,
        ]).id,
      ],
    })
    @google_and_yahoo_multi_group_admin = FactoryGirl.create(:limited_admin, {
      :id => "google_and_yahoo_multi_group_admin#{rand(999_999)}",
      :group_ids => [
        FactoryGirl.create(:admin_group, :api_scopes => [
          google_api_scope,
        ]).id,
        FactoryGirl.create(:admin_group, :api_scopes => [
          yahoo_api_scope,
        ]).id,
      ],
    })
    @google_and_yahoo_multi_scope_admin = FactoryGirl.create(:limited_admin, {
      :id => "google_and_yahoo_multi_scope_admin#{rand(999_999)}",
      :group_ids => [
        FactoryGirl.create(:admin_group, :api_scopes => [
          google_api_scope,
          yahoo_api_scope,
        ]).id,
      ],
    })
  end

  shared_examples "admin save permissions" do |method, action|
    it "forbids limited admins from setting the superuser attribute" do
      attributes = FactoryGirl.attributes_for(:limited_admin, {
        :superuser => "1",
      })

      expect do
        admin_token_auth(@google_admin)
        send(method, action, params.merge(:admin => attributes))

        response.status.should eql(403)
        data = MultiJson.load(response.body)
        data.keys.should eql(["errors"])
      end.to_not change { Admin.count }
    end

    it "allows superusers to enable the superuser attribute" do
      attributes = FactoryGirl.attributes_for(:limited_admin, {
        :superuser => "1",
      })

      expect do
        admin_token_auth(@admin)
        send(method, action, params.merge(:admin => attributes))

        response.status.should eql(success_response_status)
        data = MultiJson.load(response.body)
        admin = Admin.find(data["admin"]["id"])
        admin.superuser.should eql(true)
      end.to change { Admin.count }.by(success_record_change_count)
    end

    it "allows superusers to disable the superuser attribute" do
      attributes = FactoryGirl.attributes_for(:limited_admin, {
        :superuser => "0",
      })

      expect do
        admin_token_auth(@admin)
        send(method, action, params.merge(:admin => attributes))

        response.status.should eql(success_response_status)
        data = MultiJson.load(response.body)
        admin = Admin.find(data["admin"]["id"])
        admin.superuser.should eql(false)
      end.to change { Admin.count }.by(success_record_change_count)
    end

    it "forbids limited admins from interacting with a superuser admin account" do
      attributes = FactoryGirl.attributes_for(:admin, {
        :name => "New Name",
      })

      expect do
        admin_token_auth(@google_admin)
        send(method, action, params.merge(:admin => attributes))

        response.status.should eql(403)
        data = MultiJson.load(response.body)
        data.keys.should eql(["errors"])
      end.to_not change { Admin.count }
    end

    it "allows superusers to interact with other superuser accounts" do
      attributes = FactoryGirl.attributes_for(:admin, {
        :name => "New Name",
      })

      expect do
        admin_token_auth(@admin)
        send(method, action, params.merge(:admin => attributes))

        response.status.should eql(success_response_status)
        data = MultiJson.load(response.body)
        admin = Admin.find(data["admin"]["id"])
        admin.name.should eql("New Name")
      end.to change { Admin.count }.by(success_record_change_count)
    end

    it "return validation error if account has no groups and isn't a superuser" do
      attributes = FactoryGirl.attributes_for(:admin, {
        :superuser => false,
        :group_ids => [],
      })

      expect do
        admin_token_auth(@google_admin)
        send(method, action, params.merge(:admin => attributes))

        response.status.should eql(422)
        data = MultiJson.load(response.body)
        data.keys.should eql(["errors"])
        data["errors"].first["field"].should eql("groups")
      end.to_not change { Admin.count }
    end
  end

  describe "GET index" do
    describe "admin permissions" do
      it "includes all admins for superuser admins" do
        admin_token_auth(@admin)
        get :index, :format => "json"

        data = MultiJson.load(response.body)
        admin_ids = data["data"].map { |admin| admin["id"] }
        admin_ids.sort.should eql([
          @admin.id,
          @superuser_with_groups_admin.id,
          @google_admin.id,
          @google_single_scope_admin.id,
          @unauthorized_google_admin.id,
          @yahoo_admin.id,
          @google_and_yahoo_multi_group_admin.id,
          @google_and_yahoo_multi_scope_admin.id,
        ].sort)
      end

      it "includes admins the admin has access to" do
        admin_token_auth(@google_admin)
        get :index, :format => "json"

        data = MultiJson.load(response.body)
        admin_ids = data["data"].map { |admin| admin["id"] }
        admin_ids.sort.should eql([
          @google_admin.id,
          @google_single_scope_admin.id,
          @unauthorized_google_admin.id,
        ].sort)
      end

      it "excludes admins the admin does not have access to" do
        admin_token_auth(@google_admin)
        get :index, :format => "json"

        data = MultiJson.load(response.body)
        admin_ids = data["data"].map { |admin| admin["id"] }
        admin_ids.should_not include(@admin.id)
        admin_ids.should_not include(@yahoo_admin.id)
      end

      it "excludes admins the admin only has partial access to" do
        admin_token_auth(@google_admin)
        get :index, :format => "json"

        data = MultiJson.load(response.body)
        admin_ids = data["data"].map { |admin| admin["id"] }
        admin_ids.should_not include(@google_and_yahoo_multi_group_admin.id)
        admin_ids.should_not include(@google_and_yahoo_multi_scope_admin.id)
      end

      it "excludes all admins for admins without proper access" do
        admin_token_auth(@unauthorized_google_admin)
        get :index, :format => "json"

        data = MultiJson.load(response.body)
        data["data"].length.should eql(0)
      end
    end
  end

  describe "GET show" do
  end

  describe "POST create" do
    let(:params) do
      {
        :format => "json",
      }
    end
    let(:success_response_status) { 201 }
    let(:success_record_change_count) { 1 }

    it_behaves_like "admin save permissions", :post, :create
  end

  describe "PUT update" do
    before(:each) do
      @update_admin = FactoryGirl.create(:admin)
    end

    let(:params) do
      {
        :format => "json",
        :id => @update_admin.id,
      }
    end
    let(:success_response_status) { 200 }
    let(:success_record_change_count) { 0 }

    it_behaves_like "admin save permissions", :put, :update
  end

  describe "DELETE destroy" do
  end
end
