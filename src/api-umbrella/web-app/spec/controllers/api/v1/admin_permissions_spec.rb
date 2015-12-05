require "spec_helper"

describe Api::V1::AdminPermissionsController do
  before(:all) do
    @admin = FactoryGirl.create(:admin)
  end

  describe "GET index" do
    it "returns the expected permissions in the display order" do
      admin_token_auth(@admin)
      get :index, :format => "json"

      data = MultiJson.load(response.body)
      permission_names = data["admin_permissions"].map { |permission| permission["name"] }
      permission_names.should eql([
        "Analytics",
        "API Users - View",
        "API Users - Manage",
        "Admin Accounts - View & Manage",
        "API Backend Configuration - View & Manage",
        "API Backend Configuration - Publish",
      ])

      data["admin_permissions"].first["id"].should eql("analytics")
      data["admin_permissions"].first["name"].should eql("Analytics")
      data["admin_permissions"].first["display_order"].should eql(1)
    end
  end
end
