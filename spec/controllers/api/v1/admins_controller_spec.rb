require 'spec_helper'

describe Api::V1::AdminsController do
  before(:all) do
    Admin.delete_all

    google_api_scope = FactoryGirl.create(:google_api_scope)
    google2_api_scope = FactoryGirl.create(:google_api_scope, :host => "example.com")
    yahoo_api_scope = FactoryGirl.create(:yahoo_api_scope)

    @admin = FactoryGirl.create(:admin)
    @google_admin = FactoryGirl.create(:limited_admin, :groups => [
      FactoryGirl.create(:admin_group, :admin_manage_permission, :api_scopes => [
        google_api_scope,
        google2_api_scope,
      ]),
    ])
    @google_single_scope_admin = FactoryGirl.create(:limited_admin, :groups => [
      FactoryGirl.create(:admin_group, :admin_manage_permission, :api_scopes => [
        google_api_scope,
      ]),
    ])
    @unauthorized_google_admin = FactoryGirl.create(:limited_admin, :groups => [
      FactoryGirl.create(:admin_group, :user_manage_permission, :api_scopes => [
        google_api_scope,
      ]),
    ])
    @yahoo_admin = FactoryGirl.create(:limited_admin, :groups => [
      FactoryGirl.create(:admin_group, :api_scopes => [
        yahoo_api_scope,
      ]),
    ])
    @google_and_yahoo_multi_group_admin = FactoryGirl.create(:limited_admin, :groups => [
      FactoryGirl.create(:admin_group, :api_scopes => [
        google_api_scope,
      ]),
      FactoryGirl.create(:admin_group, :api_scopes => [
        yahoo_api_scope,
      ]),
    ])
    @google_and_yahoo_multi_scope_admin = FactoryGirl.create(:limited_admin, :groups => [
      FactoryGirl.create(:admin_group, :api_scopes => [
        google_api_scope,
        yahoo_api_scope,
      ]),
    ])
  end

  describe "GET index" do
    describe "admin permissions" do
      it "includes all admins for superuser admins" do
        admin_token_auth(@admin)
        get :index, :format => "json"

        data = MultiJson.load(response.body)
        admin_ids = data["data"].map { |admin| admin["id"] }
        admin_ids.should include(@admin.id)
        admin_ids.should include(@google_admin.id)
        admin_ids.should include(@google_single_scope_admin.id)
        admin_ids.should include(@unauthorized_google_admin.id)
        admin_ids.should include(@yahoo_admin.id)
        admin_ids.should include(@google_and_yahoo_multi_group_admin.id)
        admin_ids.should include(@google_and_yahoo_multi_scope_admin.id)
      end

      it "includes admins the admin has access to" do
        admin_token_auth(@google_admin)
        get :index, :format => "json"

        data = MultiJson.load(response.body)
        admin_ids = data["data"].map { |admin| admin["id"] }
        admin_ids.should include(@google_admin.id)
        admin_ids.should include(@google_single_scope_admin.id)
        admin_ids.should include(@unauthorized_google_admin.id)
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
  end

  describe "PUT update" do
  end

  describe "DELETE destroy" do
  end
end
