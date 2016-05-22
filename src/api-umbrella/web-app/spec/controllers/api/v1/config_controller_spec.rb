require 'spec_helper'

describe Api::V1::ConfigController do
  before(:all) do
    @admin = FactoryGirl.create(:admin)
    @google_admin = FactoryGirl.create(:limited_admin, :groups => [FactoryGirl.create(:google_admin_group, :backend_publish_permission)])
    @unauthorized_google_admin = FactoryGirl.create(:limited_admin, :groups => [FactoryGirl.create(:google_admin_group, :backend_manage_permission)])
  end

  before(:each) do
    Api.delete_all
    ConfigVersion.delete_all
  end

  describe "GET pending_changes" do
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
        %w(_id version created_by created_at updated_at updated_by).each do |field|
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
          "backend_host",
          "backend_protocol",
          "balance_algorithm",
          "frontend_host",
          "name",
          "servers",
          "- host",
          "  port",
          "sort_order",
          "url_matches",
          "- backend_prefix",
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
        api_data["active_yaml"].should include("name: #{@api.name}")
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
        api_data["active_yaml"].should include("name: #{@api.name}")
        api_data["pending"]["_id"].should eql(@api.id)
        api_data["pending_yaml"].should include("name: #{@api.name}")
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
        api_data["pending_yaml"].should include("name: #{@api.name}")
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
        admin_token_auth(@unauthorized_google_admin)
        get :pending_changes, :format => "json"

        data = MultiJson.load(response.body)
        api_ids = data["config"]["apis"]["identical"].map { |api| api["pending"]["_id"] }
        api_ids.length.should eql(0)
      end
    end
  end

  describe "POST publish" do
    it "publishes changes when there was no pre-existing published config" do
      ConfigVersion.count.should eql(0)

      api = FactoryGirl.create(:api)
      config = {
        :apis => {
          api.id => { :publish => "1" },
        }
      }

      admin_token_auth(@admin)
      post :publish, :format => "json", :config => config

      ConfigVersion.count.should eql(1)
      active_config = ConfigVersion.active_config
      active_config["apis"].length.should eql(1)
    end

    it "publishes changes when there was a pre-existing published config" do
      FactoryGirl.create(:api)
      ConfigVersion.publish!(ConfigVersion.pending_config)
      ConfigVersion.count.should eql(1)

      api = FactoryGirl.create(:api)
      config = {
        :apis => {
          api.id => { :publish => "1" },
        }
      }

      admin_token_auth(@admin)
      post :publish, :format => "json", :config => config

      ConfigVersion.count.should eql(2)
      active_config = ConfigVersion.active_config
      active_config["apis"].length.should eql(2)
    end

    it "combines the newly published config and in sorted order" do
      api1 = FactoryGirl.create(:api, :sort_order => 40)
      api2 = FactoryGirl.create(:api, :sort_order => 15)
      ConfigVersion.publish!(ConfigVersion.pending_config)
      ConfigVersion.count.should eql(1)

      api3 = FactoryGirl.create(:api, :sort_order => 90)
      api4 = FactoryGirl.create(:api, :sort_order => 1)
      api5 = FactoryGirl.create(:api, :sort_order => 50)
      api6 = FactoryGirl.create(:api, :sort_order => 20)

      config = {
        :apis => {
          api3.id => { :publish => "1" },
          api4.id => { :publish => "1" },
          api5.id => { :publish => "1" },
          api6.id => { :publish => "1" },
        }
      }

      admin_token_auth(@admin)
      post :publish, :format => "json", :config => config

      active_config = ConfigVersion.active_config
      active_config["apis"].map { |api| api["_id"] }.should eql([
        api4.id,
        api2.id,
        api6.id,
        api1.id,
        api5.id,
        api3.id,
      ])
    end

    it "only publishes the selected apis" do
      api1 = FactoryGirl.create(:api, :name => "Before")
      ConfigVersion.publish!(ConfigVersion.pending_config)

      api1.update_attribute(:name, "After")
      api2 = FactoryGirl.create(:api)
      api3 = FactoryGirl.create(:api)

      config = {
        :apis => {
          api2.id => { :publish => "1" },
          api3.id => { :publish => "0" },
        }
      }

      admin_token_auth(@admin)
      post :publish, :format => "json", :config => config

      active_config = ConfigVersion.active_config
      active_config["apis"].map { |api| api["_id"] }.sort.should eql([
        api1.id,
        api2.id,
      ].sort)

      api1_config = active_config["apis"].detect { |api| api["_id"] == api1.id }
      api1_config["name"].should eql("Before")
    end

    it "does nothing when no changes are submited" do
      api1 = FactoryGirl.create(:api, :name => "Before")
      initial = ConfigVersion.publish!(ConfigVersion.pending_config)
      initial.reload

      api1.update_attribute(:name, "After")
      FactoryGirl.create(:api)
      FactoryGirl.create(:api)

      admin_token_auth(@admin)
      post :publish, :format => "json", :config => {}

      active = ConfigVersion.active
      active.id.should be_kind_of(Moped::BSON::ObjectId)
      active.id.should eql(initial.id)
      active.version.should be_kind_of(Time)
      active.version.should eql(initial.version)
      active_config = active.config
      active_config["apis"].map { |api| api["_id"] }.sort.should eql([
        api1.id,
      ].sort)

      api1_config = active_config["apis"].detect { |api| api["_id"] == api1.id }
      api1_config["name"].should eql("Before")
    end

    describe "admin permissions" do
      before(:each) do
        @api = FactoryGirl.create(:api)
        @google_api = FactoryGirl.create(:google_api)
        @google_extra_url_match_api = FactoryGirl.create(:google_extra_url_match_api)
        @yahoo_api = FactoryGirl.create(:yahoo_api)
      end

      it "allows superusers to publish any api" do
        config = {
          :apis => {
            @api.id => { :publish => "1" },
            @google_api.id => { :publish => "1" },
            @google_extra_url_match_api.id => { :publish => "1" },
            @yahoo_api.id => { :publish => "1" },
          }
        }

        admin_token_auth(@admin)
        post :publish, :format => "json", :config => config

        response.status.should eql(201)
        active_config = ConfigVersion.active_config
        active_config["apis"].length.should eql(4)
        active_config["apis"].map { |api| api["_id"] }.sort.should eql([
          @api.id,
          @google_api.id,
          @google_extra_url_match_api.id,
          @yahoo_api.id,
        ].sort)
      end

      it "allows limited admins to publish apis they have access to" do
        config = {
          :apis => {
            @google_api.id => { :publish => "1" },
          }
        }

        admin_token_auth(@google_admin)
        post :publish, :format => "json", :config => config

        response.status.should eql(201)
        active_config = ConfigVersion.active_config
        active_config["apis"].length.should eql(1)
        active_config["apis"].first["_id"].should eql(@google_api.id)
      end

      it "forbids limited admins from publishing apis they do not have access to" do
        config = {
          :apis => {
            @yahoo_api.id => { :publish => "1" },
          }
        }

        admin_token_auth(@google_admin)
        post :publish, :format => "json", :config => config

        response.status.should eql(403)
        data = MultiJson.load(response.body)
        data.keys.should eql(["errors"])
        ConfigVersion.active_config.should eql(nil)
      end

      it "forbids limited admins from publishing apis they only have partial access to" do
        config = {
          :apis => {
            @google_extra_url_match_api.id => { :publish => "1" },
          }
        }

        admin_token_auth(@google_admin)
        post :publish, :format => "json", :config => config

        response.status.should eql(403)
        data = MultiJson.load(response.body)
        data.keys.should eql(["errors"])
        ConfigVersion.active_config.should eql(nil)
      end

      it "forbids admins with proper access" do
        config = {
          :apis => {
            @google_api.id => { :publish => "1" },
          }
        }

        admin_token_auth(@unauthorized_google_admin)
        post :publish, :format => "json", :config => config

        response.status.should eql(403)
        data = MultiJson.load(response.body)
        data.keys.should eql(["errors"])
        ConfigVersion.active_config.should eql(nil)
      end
    end

    describe "transitionary https" do
      ["transition_return_error", "transition_return_redirect"].each do |mode|
        it "sets the transition timestamp for #{mode.inspect} mode when publishing" do
          api = FactoryGirl.create(:api, {
            :settings => {
              :require_https => mode,
            },
          })
          config = {
            :apis => {
              api.id => { :publish => "1" },
            }
          }

          api.settings.require_https_transition_start_at.should eql(nil)

          admin_token_auth(@admin)
          post :publish, :format => "json", :config => config

          ConfigVersion.count.should eql(1)
          active_config = ConfigVersion.active_config

          api.reload
          api.settings.require_https_transition_start_at.should be_kind_of(Time)
          active_config["apis"][0]["settings"]["require_https_transition_start_at"].should be_kind_of(Time)
        end

        it "sets the transition timestamp for #{mode.inspect} mode in sub-settings when publishing" do
          api = FactoryGirl.create(:api, {
            :sub_settings => [
              FactoryGirl.attributes_for(:api_sub_setting, {
                :settings_attributes => FactoryGirl.attributes_for(:api_setting, {
                  :require_https => mode,
                })
              }),
            ],
          })
          config = {
            :apis => {
              api.id => { :publish => "1" },
            }
          }

          api.sub_settings[0].settings.require_https_transition_start_at.should eql(nil)

          admin_token_auth(@admin)
          post :publish, :format => "json", :config => config

          ConfigVersion.count.should eql(1)
          active_config = ConfigVersion.active_config

          api.reload
          api.sub_settings[0].settings.require_https_transition_start_at.should be_kind_of(Time)
          active_config["apis"][0]["sub_settings"][0]["settings"]["require_https_transition_start_at"].should be_kind_of(Time)
        end

        it "does not change existing transition timestamp for #{mode.inspect} mode when publishing" do
          timestamp = Time.parse("2015-01-16T06:06:28.816Z")
          api = FactoryGirl.create(:api, {
            :settings => FactoryGirl.attributes_for(:api_setting, {
              :require_https => mode,
              :require_https_transition_start_at => timestamp,
            }),
          })
          config = {
            :apis => {
              api.id => { :publish => "1" },
            }
          }

          api.settings.require_https_transition_start_at.should eql(timestamp)

          admin_token_auth(@admin)
          post :publish, :format => "json", :config => config

          ConfigVersion.count.should eql(1)
          active_config = ConfigVersion.active_config

          api.reload
          api.settings.require_https_transition_start_at.should eql(timestamp)
          active_config["apis"][0]["settings"]["require_https_transition_start_at"].should eql(timestamp)
        end

        it "does not change existing transition timestamp for #{mode.inspect} mode if the mode changes are made without publishing" do
          timestamp = Time.parse("2015-01-16T06:06:28.816Z")
          api = FactoryGirl.create(:api, {
            :settings => FactoryGirl.attributes_for(:api_setting, {
              :require_https => mode,
              :require_https_transition_start_at => timestamp,
            }),
          })

          api.settings.require_https = "required_return_error"
          api.save!

          api.settings.require_https = "required_return_redirect"
          api.save!

          api.settings.require_https = "optional"
          api.save!

          api.settings.require_https = nil
          api.save!

          api.settings.require_https = mode
          api.save!

          config = {
            :apis => {
              api.id => { :publish => "1" },
            }
          }

          api.settings.require_https_transition_start_at.should eql(timestamp)

          admin_token_auth(@admin)
          post :publish, :format => "json", :config => config

          ConfigVersion.count.should eql(1)
          active_config = ConfigVersion.active_config

          api.reload
          api.settings.require_https_transition_start_at.should eql(timestamp)
          active_config["apis"][0]["settings"]["require_https_transition_start_at"].should eql(timestamp)
        end
      end

      ["required_return_error", "required_return_redirect", "optional", nil].each do |mode|
        it "unsets the transition timestamp for #{mode.inspect} mode when publishing" do
          api = FactoryGirl.create(:api, {
            :settings => FactoryGirl.attributes_for(:api_setting, {
              :require_https => mode,
              :require_https_transition_start_at => Time.now,
            }),
          })
          config = {
            :apis => {
              api.id => { :publish => "1" },
            }
          }

          api.settings.require_https_transition_start_at.should be_kind_of(Time)

          admin_token_auth(@admin)
          post :publish, :format => "json", :config => config

          ConfigVersion.count.should eql(1)
          active_config = ConfigVersion.active_config

          api.reload
          api.settings.require_https_transition_start_at.should eql(nil)
          active_config["apis"][0]["settings"]["require_https_transition_start_at"].should eql(nil)
        end

        it "unsets the transition timestamp for #{mode.inspect} mode in sub-settings when publishing" do
          api = FactoryGirl.create(:api, {
            :sub_settings => [
              FactoryGirl.attributes_for(:api_sub_setting, {
                :settings_attributes => FactoryGirl.attributes_for(:api_setting, {
                  :require_https => mode,
                  :require_https_transition_start_at => Time.now,
                })
              }),
            ],
          })
          config = {
            :apis => {
              api.id => { :publish => "1" },
            }
          }

          api.sub_settings[0].settings.require_https_transition_start_at.should be_kind_of(Time)

          admin_token_auth(@admin)
          post :publish, :format => "json", :config => config

          ConfigVersion.count.should eql(1)
          active_config = ConfigVersion.active_config

          api.reload
          api.sub_settings[0].settings.require_https_transition_start_at.should eql(nil)
          active_config["apis"][0]["sub_settings"][0]["settings"]["require_https_transition_start_at"].should eql(nil)
        end
      end
    end
  end
end
