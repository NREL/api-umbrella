require "spec_helper"

describe Api::V1::WebsiteBackendsController do
  before(:all) do
    @admin = FactoryGirl.create(:admin)
    @amazon_root_admin = FactoryGirl.create(:limited_admin, :groups => [FactoryGirl.create(:amazon_admin_group_single_root_scope, :backend_manage_permission)])
    @unauthorized_amazon_root_admin = FactoryGirl.create(:limited_admin, :groups => [FactoryGirl.create(:amazon_admin_group_single_root_scope, :backend_publish_permission)])
    @amazon_sub_admin = FactoryGirl.create(:limited_admin, :groups => [FactoryGirl.create(:amazon_admin_group_single_sub_scope, :backend_manage_permission)])
    @amazon_multi_admin = FactoryGirl.create(:limited_admin, :groups => [FactoryGirl.create(:amazon_admin_group_multi_scope, :backend_manage_permission)])
  end

  before(:each) do
    WebsiteBackend.delete_all

    @website_backend = FactoryGirl.create(:website_backend)
    @amazon_website_backend = FactoryGirl.create(:amazon_website_backend)
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

    it "paginates results" do
      admin_token_auth(@admin)
      get :index, :format => "json", :length => "1"

      website_backend_count = WebsiteBackend.count
      website_backend_count.should be > 1

      data = MultiJson.load(response.body)
      data["recordsTotal"].should eql(website_backend_count)
      data["recordsFiltered"].should eql(website_backend_count)
      data["data"].length.should eql(1)
    end

    describe "admin permissions" do
      it "includes all website backends for superuser admins" do
        admin_token_auth(@admin)
        get :index, :format => "json"

        data = MultiJson.load(response.body)
        website_backend_ids = data["data"].map { |api| api["id"] }
        website_backend_ids.length.should eql(2)
        website_backend_ids.should include(@website_backend.id)
        website_backend_ids.should include(@amazon_website_backend.id)
      end

      it "includes website backends the admin has access to" do
        admin_token_auth(@amazon_root_admin)
        get :index, :format => "json"

        data = MultiJson.load(response.body)
        website_backend_ids = data["data"].map { |api| api["id"] }
        website_backend_ids.should include(@amazon_website_backend.id)
      end

      it "excludes website backends the admin does not have access to" do
        admin_token_auth(@amazon_root_admin)
        get :index, :format => "json"

        data = MultiJson.load(response.body)
        website_backend_ids = data["data"].map { |api| api["id"] }
        website_backend_ids.should_not include(@website_backend.id)
      end

      it "excludes website backends the admin only has partial access to" do
        admin_token_auth(@amazon_sub_admin)
        get :index, :format => "json"

        data = MultiJson.load(response.body)
        website_backend_ids = data["data"].map { |api| api["id"] }
        website_backend_ids.should_not include(@amazon_website_backend.id)
      end

      it "excludes all website backends for admins without proper access" do
        admin_token_auth(@unauthorized_amazon_root_admin)
        get :index, :format => "json"

        data = MultiJson.load(response.body)
        data["data"].length.should eql(0)
      end

      it "grants access to website backends with multiple prefixes when the admin has permissions to each prefix via separate scopes and groups" do
        admin_token_auth(@amazon_multi_admin)
        get :index, :format => "json"

        data = MultiJson.load(response.body)
        website_backend_ids = data["data"].map { |api| api["id"] }
        website_backend_ids.length.should eql(1)
        website_backend_ids.should include(@amazon_website_backend.id)
      end
    end
  end
end
