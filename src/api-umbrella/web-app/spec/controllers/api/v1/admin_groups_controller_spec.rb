require 'spec_helper'

describe Api::V1::AdminGroupsController do
  before(:each) do
    AdminGroup.delete_all
    Admin.delete_all
    @admin = FactoryGirl.create(:admin)
  end

  describe "GET index" do
    describe "admin permissions" do
      before(:each) do
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

        @google_admin = FactoryGirl.create(:limited_admin, :group_ids => [
          @google_group.id,
        ])
        @google_single_scope_admin = FactoryGirl.create(:limited_admin, :group_ids => [
          @google_single_scope_group.id,
        ])
        @unauthorized_google_admin = FactoryGirl.create(:limited_admin, :group_ids => [
          @unauthorized_google_group.id,
        ])
      end

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

    describe "admin_usernames" do
      it "returns an array of admin usernames belonging to the group" do
        group = FactoryGirl.create(:admin_group)
        admin_in_group = FactoryGirl.create(:limited_admin, :group_ids => [
          group.id,
        ])

        admin_token_auth(@admin)
        get :index, :format => "json"

        data = MultiJson.load(response.body)
        data["data"].length.should eql(1)
        data["data"][0]["admin_usernames"].should eql([admin_in_group.username])
      end

      it "sorts usernames in alphabetical order" do
        group = FactoryGirl.create(:admin_group)
        admin_in_group1 = FactoryGirl.create(:limited_admin, :username => "b", :group_ids => [
          group.id,
        ])
        admin_in_group2 = FactoryGirl.create(:limited_admin, :username => "a", :group_ids => [
          group.id,
        ])

        admin_token_auth(@admin)
        get :index, :format => "json"

        data = MultiJson.load(response.body)
        data["data"].length.should eql(1)
        data["data"][0]["admin_usernames"].should eql([admin_in_group2.username, admin_in_group1.username])
      end

      it "returns an empty array when no admins belong to a group" do
        FactoryGirl.create(:admin_group)

        admin_token_auth(@admin)
        get :index, :format => "json"

        data = MultiJson.load(response.body)
        data["data"].length.should eql(1)
        data["data"][0]["admin_usernames"].should eql([])
      end
    end
  end

  describe "GET show" do
    describe "admins" do
      it "returns metadata for the admins belonging to the group" do
        group = FactoryGirl.create(:admin_group)
        admin_in_group = FactoryGirl.create(:limited_admin, :last_sign_in_at => Time.now, :group_ids => [
          group.id,
        ])

        admin_token_auth(@admin)
        get :show, :id => group.id, :format => "json"

        data = MultiJson.load(response.body)
        data["admin_group"]["admins"].should eql([
          {
            "id" => admin_in_group.id,
            "username" => admin_in_group.username,
            "last_sign_in_at" => admin_in_group.last_sign_in_at.iso8601,
          },
        ])
      end

      it "sorts admins by username in alphabetical order" do
        group = FactoryGirl.create(:admin_group)
        admin_in_group1 = FactoryGirl.create(:limited_admin, :username => "b", :group_ids => [
          group.id,
        ])
        admin_in_group2 = FactoryGirl.create(:limited_admin, :username => "a", :group_ids => [
          group.id,
        ])

        admin_token_auth(@admin)
        get :show, :id => group.id, :format => "json"

        data = MultiJson.load(response.body)
        data["admin_group"]["admins"].map { |admin| admin["id"] }.should eql([
          admin_in_group2.id,
          admin_in_group1.id,
        ])
      end

      it "returns an empty array when no admins belong to a group" do
        group = FactoryGirl.create(:admin_group)

        admin_token_auth(@admin)
        get :show, :id => group.id, :format => "json"

        data = MultiJson.load(response.body)
        data["admin_group"]["admins"].should eql([])
      end
    end
  end

  describe "POST create" do
  end

  describe "PUT update" do
  end

  describe "DELETE destroy" do
  end
end
