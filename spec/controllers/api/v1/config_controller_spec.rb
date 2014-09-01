require 'spec_helper'

describe Api::V1::ConfigController do
  before(:all) do
    @admin = FactoryGirl.create(:admin)
    @google_admin = FactoryGirl.create(:limited_admin, :groups => [FactoryGirl.create(:google_admin_group, :backend_publish_access)])
    @unauthorized_admin = FactoryGirl.create(:limited_admin, :groups => [FactoryGirl.create(:google_admin_group, :backend_manage_access)])
  end

  describe "GET pending_changes" do
    before(:each) do
      Api.delete_all
      ConfigVersion.delete_all
    end

    it "returns apis grouped into categories" do
      admin_token_auth(@admin)
      get :pending_changes, :format => "json"

      data = MultiJson.load(response.body)
      data["config"].should be_kind_of(Hash)
      data["config"]["apis"].should be_kind_of(Hash)
      data["config"]["apis"]["deleted"].should be_kind_of(Array)
      data["config"]["apis"]["identical"].should be_kind_of(Array)
      data["config"]["apis"]["modified"].should be_kind_of(Array)
      data["config"]["apis"]["new"].should be_kind_of(Array)
    end

    describe "yaml output" do
      before(:each) do
        @api = FactoryGirl.create(:api, :name => "YAML Test")
      end

      it "omits the yaml separator" do
        admin_token_auth(@admin)
        get :pending_changes, :format => "json"

        data = MultiJson.load(response.body)
        api_data = data["config"]["apis"]["new"].first
        api_data["pending_yaml"].should_not include("---")
      end

      it "omits fields in the yaml that exist in the json output but don't matter for diff purposes" do
        admin_token_auth(@admin)
        get :pending_changes, :format => "json"

        data = MultiJson.load(response.body)
        api_data = data["config"]["apis"]["new"].first
        %w(version created_by created_at updated_at updated_by).each do |field|
          api_data["pending"][field].present?.should eql(true)
          api_data["pending_yaml"].should_not include(field)
        end
      end

      it "returns the yaml sorted in alphabetical order by key for better diff purposes" do
        admin_token_auth(@admin)
        get :pending_changes, :format => "json"

        data = MultiJson.load(response.body)
        api_data = data["config"]["apis"]["new"].first

        yaml_lines = api_data["pending_yaml"].split("\n")
        yaml_keys = yaml_lines.map { |line| line.gsub(/:.*/, "") }
        yaml_keys.should eql([
          "_id",
          "backend_host",
          "backend_protocol",
          "balance_algorithm",
          "frontend_host",
          "name",
          "servers",
          "- _id",
          "  host",
          "  port",
          "sort_order",
          "url_matches",
          "- _id",
          "  backend_prefix",
          "  frontend_prefix",
        ])
      end
    end

    describe "deleted" do
      before(:each) do
        @api = FactoryGirl.create(:api)
        ConfigVersion.publish!(ConfigVersion.pending_config)
        @api.destroy
      end

      it "considers apis deleted when they are deleted after the last config publish" do
        admin_token_auth(@admin)
        get :pending_changes, :format => "json"

        data = MultiJson.load(response.body)
        data["config"]["apis"]["deleted"].length.should eql(1)
        data["config"]["apis"]["identical"].length.should eql(0)
        data["config"]["apis"]["modified"].length.should eql(0)
        data["config"]["apis"]["new"].length.should eql(0)
      end

      it "includes the expected output for each deleted api" do
        admin_token_auth(@admin)
        get :pending_changes, :format => "json"

        data = MultiJson.load(response.body)
        api_data = data["config"]["apis"]["deleted"].first
        api_data["mode"].should eql("deleted")
        api_data["id"].should eql(@api.id)
        api_data["name"].should eql(@api.name)
        api_data["active"]["_id"].should eql(@api.id)
        api_data["active_yaml"].should include("_id: #{@api.id}")
        api_data["pending"].should eql(nil)
        api_data["pending_yaml"].should eql("")
      end
    end

    describe "identical" do
      before(:each) do
        @api = FactoryGirl.create(:api)
        ConfigVersion.publish!(ConfigVersion.pending_config)
      end

      it "considers apis identical when there are now changes after the last config publish" do
        admin_token_auth(@admin)
        get :pending_changes, :format => "json"

        data = MultiJson.load(response.body)
        data["config"]["apis"]["deleted"].length.should eql(0)
        data["config"]["apis"]["identical"].length.should eql(1)
        data["config"]["apis"]["modified"].length.should eql(0)
        data["config"]["apis"]["new"].length.should eql(0)
      end

      it "includes the expected output for each identical api" do
        admin_token_auth(@admin)
        get :pending_changes, :format => "json"

        data = MultiJson.load(response.body)
        api_data = data["config"]["apis"]["identical"].first
        api_data["mode"].should eql("identical")
        api_data["id"].should eql(@api.id)
        api_data["name"].should eql(@api.name)
        api_data["active"]["_id"].should eql(@api.id)
        api_data["active_yaml"].should include("_id: #{@api.id}")
        api_data["pending"]["_id"].should eql(@api.id)
        api_data["pending_yaml"].should include("_id: #{@api.id}")
      end
    end

    describe "modified" do
      before(:each) do
        @api = FactoryGirl.create(:api, :name => "Before")
        ConfigVersion.publish!(ConfigVersion.pending_config)
        @api.update_attribute(:name, "After")
      end

      it "considers apis modified when they are modified after the last config publish" do
        admin_token_auth(@admin)
        get :pending_changes, :format => "json"

        data = MultiJson.load(response.body)
        data["config"]["apis"]["deleted"].length.should eql(0)
        data["config"]["apis"]["identical"].length.should eql(0)
        data["config"]["apis"]["modified"].length.should eql(1)
        data["config"]["apis"]["new"].length.should eql(0)
      end

      it "includes the expected output for each modified api" do
        admin_token_auth(@admin)
        get :pending_changes, :format => "json"

        data = MultiJson.load(response.body)
        api_data = data["config"]["apis"]["modified"].first
        api_data["mode"].should eql("modified")
        api_data["id"].should eql(@api.id)
        api_data["name"].should eql("After")
        api_data["active"]["name"].should eql("Before")
        api_data["active_yaml"].should include("name: Before")
        api_data["pending"]["name"].should eql("After")
        api_data["pending_yaml"].should include("name: After")
      end
    end

    describe "new" do
      before(:each) do
        @api = FactoryGirl.create(:api)
      end

      it "considers all apis new when no previous config has been published" do
        admin_token_auth(@admin)
        get :pending_changes, :format => "json"

        data = MultiJson.load(response.body)
        data["config"]["apis"]["deleted"].length.should eql(0)
        data["config"]["apis"]["identical"].length.should eql(0)
        data["config"]["apis"]["modified"].length.should eql(0)
        data["config"]["apis"]["new"].length.should eql(1)
      end

      it "considers apis new when they are created after the last config publish" do
        ConfigVersion.publish!(ConfigVersion.pending_config)
        @google_api = FactoryGirl.create(:google_api)

        admin_token_auth(@admin)
        get :pending_changes, :format => "json"

        data = MultiJson.load(response.body)
        data["config"]["apis"]["deleted"].length.should eql(0)
        data["config"]["apis"]["identical"].length.should eql(1)
        data["config"]["apis"]["modified"].length.should eql(0)
        data["config"]["apis"]["new"].length.should eql(1)
      end

      it "includes the expected output for each new api" do
        admin_token_auth(@admin)
        get :pending_changes, :format => "json"

        data = MultiJson.load(response.body)
        api_data = data["config"]["apis"]["new"].first
        api_data["mode"].should eql("new")
        api_data["id"].should eql(@api.id)
        api_data["name"].should eql(@api.name)
        api_data["active"].should eql(nil)
        api_data["active_yaml"].should eql("")
        api_data["pending"]["_id"].should eql(@api.id)
        api_data["pending_yaml"].should include("_id: #{@api.id}")
      end
    end

    describe "admin permissions" do
      before(:each) do
        @api = FactoryGirl.create(:api)
        @google_api = FactoryGirl.create(:google_api)
        @google_extra_url_match_api = FactoryGirl.create(:google_extra_url_match_api)
        @yahoo_api = FactoryGirl.create(:yahoo_api)

        ConfigVersion.publish!(ConfigVersion.pending_config)
      end

      it "includes all apis for superuser admins" do
        admin_token_auth(@admin)
        get :pending_changes, :format => "json"

        data = MultiJson.load(response.body)
        api_ids = data["config"]["apis"]["identical"].map { |api| api["pending"]["_id"] }
        api_ids.should include(@api.id)
        api_ids.should include(@google_api.id)
        api_ids.should include(@google_extra_url_match_api.id)
        api_ids.should include(@yahoo_api.id)
      end

      it "includes apis the admin has access to" do
        admin_token_auth(@google_admin)
        get :pending_changes, :format => "json"

        data = MultiJson.load(response.body)
        api_ids = data["config"]["apis"]["identical"].map { |api| api["pending"]["_id"] }
        api_ids.should include(@google_api.id)
      end

      it "excludes apis the admin does not have access to" do
        admin_token_auth(@google_admin)
        get :pending_changes, :format => "json"

        data = MultiJson.load(response.body)
        api_ids = data["config"]["apis"]["identical"].map { |api| api["pending"]["_id"] }
        api_ids.should_not include(@yahoo_api.id)
      end

      it "excludes apis the admin only has partial access to" do
        admin_token_auth(@google_admin)
        get :pending_changes, :format => "json"

        data = MultiJson.load(response.body)
        api_ids = data["config"]["apis"]["identical"].map { |api| api["pending"]["_id"] }
        api_ids.should_not include(@google_extra_url_match_api.id)
      end

      it "excludes all apis for admins without proper access" do
        admin_token_auth(@unauthorized_admin)
        get :pending_changes, :format => "json"

        data = MultiJson.load(response.body)
        api_ids = data["config"]["apis"]["identical"].map { |api| api["pending"]["_id"] }
        api_ids.length.should eql(0)
      end
    end
  end

  describe "POST publish" do
  end
end
