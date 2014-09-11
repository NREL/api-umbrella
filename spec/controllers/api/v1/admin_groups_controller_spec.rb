require 'spec_helper'

describe Api::V1::AdminGroupsController do
  before(:all) do
    AdminGroup.delete_all

    google_api_scope = FactoryGirl.create(:google_api_scope)
    google2_api_scope = FactoryGirl.create(:google_api_scope, :host => "example.com")
    yahoo_api_scope = FactoryGirl.create(:yahoo_api_scope)

    @group = FactoryGirl.create(:admin_group)
    @google_group = FactoryGirl.create(:admin_group, :admin_manage_permission, :api_scopes => [
      google_api_scope,
      google2_api_scope,
    ])
    @google_single_scope_group = FactoryGirl.create(:admin_group, :admin_manage_permission, :api_scopes => [
      google_api_scope,
    ])
    @unauthorized_google_group = FactoryGirl.create(:admin_group, :user_manage_permission, :api_scopes => [
      google_api_scope,
    ])
    @yahoo_group = FactoryGirl.create(:admin_group, :api_scopes => [
      yahoo_api_scope,
    ])
    @google_and_yahoo_multi_scope_group = FactoryGirl.create(:admin_group, :api_scopes => [
      google_api_scope,
      yahoo_api_scope,
    ])

    @admin = FactoryGirl.create(:admin)
    @google_admin = FactoryGirl.create(:limited_admin, :groups => [
      @google_group,
    ])
    @google_single_scope_admin = FactoryGirl.create(:limited_admin, :groups => [
      @google_single_scope_group,
    ])
    @unauthorized_google_admin = FactoryGirl.create(:limited_admin, :groups => [
      @unauthorized_google_group,
    ])
  end

  describe "GET index" do
    describe "admin permissions" do
      it "includes all groups for superuser admins" do
        admin_token_auth(@admin)
        get :index, :format => "json"

        data = MultiJson.load(response.body)
        group_ids = data["data"].map { |group| group["id"] }
        group_ids.should include(@group.id)
        group_ids.should include(@google_group.id)
        group_ids.should include(@google_single_scope_group.id)
        group_ids.should include(@unauthorized_google_group.id)
        group_ids.should include(@yahoo_group.id)
        group_ids.should include(@google_and_yahoo_multi_scope_group.id)
      end

      it "includes groups the admin has access to" do
        admin_token_auth(@google_admin)
        get :index, :format => "json"

        data = MultiJson.load(response.body)
        group_ids = data["data"].map { |group| group["id"] }
        group_ids.should include(@google_group.id)
        group_ids.should include(@google_single_scope_group.id)
        group_ids.should include(@unauthorized_google_group.id)
      end

      it "excludes groups the admin does not have access to" do
        admin_token_auth(@google_admin)
        get :index, :format => "json"

        data = MultiJson.load(response.body)
        group_ids = data["data"].map { |group| group["id"] }
        group_ids.should_not include(@group.id)
        group_ids.should_not include(@yahoo_group.id)
      end

      it "excludes groups the admin only has partial access to" do
        admin_token_auth(@google_admin)
        get :index, :format => "json"

        data = MultiJson.load(response.body)
        group_ids = data["data"].map { |group| group["id"] }
        group_ids.should_not include(@google_and_yahoo_multi_scope_group.id)
      end

      it "excludes all groups for admins without proper access" do
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
