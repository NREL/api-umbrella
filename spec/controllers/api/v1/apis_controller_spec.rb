require 'spec_helper'

describe Api::V1::ApisController do
  before(:all) do
    @admin = FactoryGirl.create(:admin)
    @google_admin = FactoryGirl.create(:limited_admin, :groups => [FactoryGirl.create(:google_admin_group, :backend_manage_permission)])
    @unauthorized_google_admin = FactoryGirl.create(:limited_admin, :groups => [FactoryGirl.create(:google_admin_group, :backend_publish_permission)])
    @bing_single_all_scope_admin = FactoryGirl.create(:limited_admin, :groups => [FactoryGirl.create(:bing_admin_group_single_all_scope, :backend_manage_permission)])
    @bing_single_restricted_scope_admin = FactoryGirl.create(:limited_admin, :groups => [FactoryGirl.create(:bing_admin_group_single_restricted_scope, :backend_manage_permission)])
    @bing_multi_scope_admin = FactoryGirl.create(:limited_admin, :groups => [FactoryGirl.create(:bing_admin_group_multi_scope, :backend_manage_permission)])
  end

  before(:each) do
    Api.delete_all

    @api = FactoryGirl.create(:api, {
      :settings => FactoryGirl.attributes_for(:api_setting, {
        :required_roles => [
          "test-write",
        ],
      }),
    })
    @google_api = FactoryGirl.create(:google_api)
    @google2_api = FactoryGirl.create(:google_api, {
      :settings => FactoryGirl.attributes_for(:api_setting, {
        :required_roles => [
          "google2-write",
        ],
      }),
    })
    @google_extra_url_match_api = FactoryGirl.create(:google_extra_url_match_api)
    @yahoo_api = FactoryGirl.create(:yahoo_api)
    @bing_api = FactoryGirl.create(:bing_api)
    @bing_search_api = FactoryGirl.create(:bing_search_api)
    @empty_url_prefixes_api = FactoryGirl.build(:google_api, {
      :url_matches => [],
    })
    @empty_url_prefixes_api.save!(:validate => false)
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
        api_ids.length.should eql(8)
        api_ids.should include(@api.id)
        api_ids.should include(@google_api.id)
        api_ids.should include(@google2_api.id)
        api_ids.should include(@google_extra_url_match_api.id)
        api_ids.should include(@yahoo_api.id)
        api_ids.should include(@bing_api.id)
        api_ids.should include(@bing_search_api.id)
        api_ids.should include(@empty_url_prefixes_api.id)
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
        admin_token_auth(@unauthorized_google_admin)
        get :index, :format => "json"

        data = MultiJson.load(response.body)
        data["data"].length.should eql(0)
      end

      it "grants access to apis for any apis falling under the prefix of the scope" do
        admin_token_auth(@bing_single_all_scope_admin)
        get :index, :format => "json"

        data = MultiJson.load(response.body)
        api_ids = data["data"].map { |api| api["id"] }
        api_ids.length.should eql(2)
        api_ids.should include(@bing_api.id)
        api_ids.should include(@bing_search_api.id)
      end

      it "grants access to apis with multiple prefixes when the admin has permissions to each prefix via separate scopes and groups" do
        admin_token_auth(@bing_multi_scope_admin)
        get :index, :format => "json"

        data = MultiJson.load(response.body)
        api_ids = data["data"].map { |api| api["id"] }
        api_ids.length.should eql(2)
        api_ids.should include(@bing_api.id)
        api_ids.should include(@bing_search_api.id)
      end

      it "only grants access to apis when the admin has permission to all of the url prefixes" do
        admin_token_auth(@bing_single_restricted_scope_admin)
        get :index, :format => "json"

        data = MultiJson.load(response.body)
        api_ids = data["data"].map { |api| api["id"] }
        api_ids.should_not include(@bing_api.id)
        api_ids.length.should eql(1)
        api_ids.should include(@bing_search_api.id)
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

      it "allows admins to view apis within the scope it has access to" do
        admin_token_auth(@google_admin)
        get :show, :format => "json", :id => @google_api.id

        response.status.should eql(200)
        data = MultiJson.load(response.body)
        data["api"]["id"].should eql(@google_api.id)
      end

      it "prevents admins from viewing apis outside the scope it has access to" do
        admin_token_auth(@google_admin)
        get :show, :format => "json", :id => @google_extra_url_match_api.id

        response.status.should eql(403)
        data = MultiJson.load(response.body)
        data.keys.should eql(["errors"])
      end

      it "forbids admins without proper access" do
        admin_token_auth(@unauthorized_google_admin)
        get :show, :format => "json", :id => @google_api.id

        response.status.should eql(403)
        data = MultiJson.load(response.body)
        data.keys.should eql(["errors"])
      end

      it "prevents limited admins from viewing incomplete apis without url prefixes" do
        admin_token_auth(@google_admin)
        get :show, :format => "json", :id => @empty_url_prefixes_api.id

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
        admin_token_auth(@unauthorized_google_admin)
        attributes = FactoryGirl.attributes_for(:google_api)

        expect do
          post :create, :format => "json", :api => attributes
          response.status.should eql(403)
          data = MultiJson.load(response.body)
          data.keys.should eql(["errors"])
        end.to_not change { Api.count }
      end
    end

    describe "admin role permissions" do
      it "allows superuser admins to assign any roles" do
        existing_roles = ApiUserRole.all
        existing_roles.should include("test-write")
        existing_roles.should include("google-write")
        existing_roles.should include("yahoo-write")
        existing_roles.should_not include("new-write")

        admin_token_auth(@admin)
        attributes = FactoryGirl.attributes_for(:api, {
          :settings => FactoryGirl.attributes_for(:api_setting, {
            :required_roles => [
              "test-write",
              "google-write",
              "yahoo-write",
              "new-write",
              "new-write#{rand(999_999)}",
            ],
          }),
          :sub_settings => [
            FactoryGirl.attributes_for(:api_sub_setting, {
              :settings => FactoryGirl.attributes_for(:api_setting, {
                :required_roles => [
                  "test-write",
                  "google-write",
                  "yahoo-write",
                  "new-write",
                  "new-write#{rand(999_999)}",
                ],
              })
            }),
          ],
        })

        expect do
          post :create, :format => "json", :api => attributes
          response.status.should eql(201)
          data = MultiJson.load(response.body)
          data["api"]["settings"]["required_roles"].should eql(attributes[:settings][:required_roles])
          data["api"]["sub_settings"][0]["settings"]["required_roles"].should eql(attributes[:sub_settings][0][:settings][:required_roles])
        end.to change { Api.count }.by(1)
      end

      it "allows limited admins to assign any unused role" do
        admin_token_auth(@google_admin)
        attributes = FactoryGirl.attributes_for(:google_api, {
          :settings => FactoryGirl.attributes_for(:api_setting, {
            :required_roles => [
              "new-settings-role#{rand(999_999)}",
            ],
          }),
          :sub_settings => [
            FactoryGirl.attributes_for(:api_sub_setting, {
              :settings => FactoryGirl.attributes_for(:api_setting, {
                :required_roles => [
                  "new-sub-settings-role#{rand(999_999)}",
                ],
              }),
            }),
          ],
        })

        expect do
          post :create, :format => "json", :api => attributes
          response.status.should eql(201)
          data = MultiJson.load(response.body)
          data["api"]["settings"]["required_roles"].should eql(attributes[:settings][:required_roles])
          data["api"]["sub_settings"][0]["settings"]["required_roles"].should eql(attributes[:sub_settings][0][:settings][:required_roles])
        end.to change { Api.count }.by(1)
      end

      it "allows limited admins to assign an existing role that exists within its scope" do
        existing_roles = ApiUserRole.all
        existing_roles.should include("google-write")

        admin_token_auth(@google_admin)
        attributes = FactoryGirl.attributes_for(:google_api, {
          :settings => FactoryGirl.attributes_for(:api_setting, {
            :required_roles => [
              "google-write",
            ],
          }),
          :sub_settings => [
            FactoryGirl.attributes_for(:api_sub_setting, {
              :settings => FactoryGirl.attributes_for(:api_setting, {
                :required_roles => [
                  "google-write",
                ],
              }),
            }),
          ],
        })

        expect do
          post :create, :format => "json", :api => attributes
          response.status.should eql(201)
          data = MultiJson.load(response.body)
          data["api"]["name"].should eql(attributes[:name])
        end.to change { Api.count }.by(1)
      end

      it "forbids limited admins from assigning an existing role that exists outside its scope at the settings level" do
        existing_roles = ApiUserRole.all
        existing_roles.should include("yahoo-write")

        admin_token_auth(@google_admin)
        attributes = FactoryGirl.attributes_for(:google_api, {
          :settings => FactoryGirl.attributes_for(:api_setting, {
            :required_roles => [
              "yahoo-write",
            ],
          }),
        })

        expect do
          post :create, :format => "json", :api => attributes
          response.status.should eql(403)
          data = MultiJson.load(response.body)
          data.keys.should eql(["errors"])
        end.to_not change { Api.count }
      end

      it "forbids limited admins from assigning an existing role that exists outside its scope at the sub-settings level" do
        existing_roles = ApiUserRole.all
        existing_roles.should include("yahoo-write")

        admin_token_auth(@google_admin)
        attributes = FactoryGirl.attributes_for(:google_api, {
          :sub_settings => [
            FactoryGirl.attributes_for(:api_sub_setting, {
              :settings => FactoryGirl.attributes_for(:api_setting, {
                :required_roles => [
                  "yahoo-write",
                ],
              }),
            }),
          ],
        })

        expect do
          post :create, :format => "json", :api => attributes
          response.status.should eql(403)
          data = MultiJson.load(response.body)
          data.keys.should eql(["errors"])
        end.to_not change { Api.count }
      end

      it "forbids limited admins from assigning an existing role that exists in an api the admin only has partial access to" do
        existing_roles = ApiUserRole.all
        existing_roles.should include("google-extra-write")

        admin_token_auth(@google_admin)
        attributes = FactoryGirl.attributes_for(:google_api, {
          :sub_settings => [
            FactoryGirl.attributes_for(:api_sub_setting, {
              :settings => FactoryGirl.attributes_for(:api_setting, {
                :required_roles => [
                  "google-extra-write",
                ],
              }),
            }),
          ],
        })

        expect do
          post :create, :format => "json", :api => attributes
          response.status.should eql(403)
          data = MultiJson.load(response.body)
          data.keys.should eql(["errors"])
        end.to_not change { Api.count }
      end

      it "forbids limited admins from assigning a new role beginning with 'api-umbrella'" do
        admin_token_auth(@google_admin)
        attributes = FactoryGirl.attributes_for(:api, {
          :settings => FactoryGirl.attributes_for(:api_setting, {
            :required_roles => [
              "api-umbrella#{rand(999_999)}",
            ],
          }),
        })

        expect do
          post :create, :format => "json", :api => attributes
          response.status.should eql(403)
          data = MultiJson.load(response.body)
          data.keys.should eql(["errors"])
        end.to_not change { Api.count }
      end

      it "allows superuser admins to assign a new role beginning with 'api-umbrella'" do
        admin_token_auth(@admin)
        attributes = FactoryGirl.attributes_for(:api, {
          :settings => FactoryGirl.attributes_for(:api_setting, {
            :required_roles => [
              "api-umbrella#{rand(999_999)}",
            ],
          }),
        })

        expect do
          post :create, :format => "json", :api => attributes
          response.status.should eql(201)
          data = MultiJson.load(response.body)
          data["api"]["name"].should eql(attributes[:name])
        end.to change { Api.count }.by(1)
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
        admin_token_auth(@unauthorized_google_admin)
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

    describe "admin role permissions" do
      it "allows superuser admins to assign any roles" do
        existing_roles = ApiUserRole.all
        existing_roles.should include("test-write")
        existing_roles.should include("google-write")
        existing_roles.should include("yahoo-write")
        existing_roles.should_not include("new-write")

        admin_token_auth(@admin)
        attributes = FactoryGirl.attributes_for(:api, {
          :settings => FactoryGirl.attributes_for(:api_setting, {
            :required_roles => [
              "test-write",
              "google-write",
              "yahoo-write",
              "new-write",
              "new-write#{rand(999_999)}",
            ],
          }),
          :sub_settings => [
            FactoryGirl.attributes_for(:api_sub_setting, {
              :settings => FactoryGirl.attributes_for(:api_setting, {
                :required_roles => [
                  "test-write",
                  "google-write",
                  "yahoo-write",
                  "new-write",
                  "new-write#{rand(999_999)}",
                ],
              })
            }),
          ],
        })
        put :update, :format => "json", :id => @api.id, :api => attributes

        response.status.should eql(204)
        @api = Api.find(@api.id)
        @api.settings.required_roles.should eql(attributes[:settings][:required_roles])
        @api.sub_settings[0].settings.required_roles.should eql(attributes[:sub_settings][0][:settings][:required_roles])
      end

      it "allows limited admins to assign any unused role" do
        admin_token_auth(@google_admin)
        attributes = FactoryGirl.attributes_for(:google_api, {
          :settings => FactoryGirl.attributes_for(:api_setting, {
            :required_roles => [
              "new-settings-role#{rand(999_999)}",
            ],
          }),
          :sub_settings => [
            FactoryGirl.attributes_for(:api_sub_setting, {
              :settings => FactoryGirl.attributes_for(:api_setting, {
                :required_roles => [
                  "new-sub-settings-role#{rand(999_999)}",
                ],
              }),
            }),
          ],
        })
        put :update, :format => "json", :id => @google_api.id, :api => attributes

        response.status.should eql(204)
        @google_api = Api.find(@google_api.id)
        @google_api.settings.required_roles.should eql(attributes[:settings][:required_roles])
        @google_api.sub_settings[0].settings.required_roles.should eql(attributes[:sub_settings][0][:settings][:required_roles])
      end

      it "allows limited admins to assign an existing role that exists within its scope" do
        existing_roles = ApiUserRole.all
        existing_roles.should include("google2-write")

        admin_token_auth(@google_admin)
        attributes = FactoryGirl.attributes_for(:google_api, {
          :settings => FactoryGirl.attributes_for(:api_setting, {
            :required_roles => [
              "google2-write",
            ],
          }),
          :sub_settings => [
            FactoryGirl.attributes_for(:api_sub_setting, {
              :settings => FactoryGirl.attributes_for(:api_setting, {
                :required_roles => [
                  "google2-write",
                ],
              }),
            }),
          ],
        })
        put :update, :format => "json", :id => @google_api.id, :api => attributes

        response.status.should eql(204)
        @google_api = Api.find(@google_api.id)
        @google_api.settings.required_roles.should eql(attributes[:settings][:required_roles])
        @google_api.sub_settings[0].settings.required_roles.should eql(attributes[:sub_settings][0][:settings][:required_roles])
      end

      it "forbids limited admins from assigning an existing role that exists outside its scope at the settings level" do
        existing_roles = ApiUserRole.all
        existing_roles.should include("yahoo-write")

        admin_token_auth(@google_admin)
        attributes = FactoryGirl.attributes_for(:google_api, {
          :settings => FactoryGirl.attributes_for(:api_setting, {
            :required_roles => [
              "yahoo-write",
            ],
          }),
        })
        put :update, :format => "json", :id => @google_api.id, :api => attributes

        response.status.should eql(403)
        data = MultiJson.load(response.body)
        data.keys.should eql(["errors"])
        @google_api = Api.find(@google_api.id)
        @google_api.roles.should_not include("yahoo-write")
      end

      it "forbids limited admins from assigning an existing role that exists outside its scope at the sub-settings level" do
        existing_roles = ApiUserRole.all
        existing_roles.should include("yahoo-write")

        admin_token_auth(@google_admin)
        attributes = FactoryGirl.attributes_for(:google_api, {
          :sub_settings => [
            FactoryGirl.attributes_for(:api_sub_setting, {
              :settings => FactoryGirl.attributes_for(:api_setting, {
                :required_roles => [
                  "yahoo-write",
                ],
              }),
            }),
          ],
        })
        put :update, :format => "json", :id => @google_api.id, :api => attributes

        response.status.should eql(403)
        data = MultiJson.load(response.body)
        data.keys.should eql(["errors"])
        @google_api = Api.find(@google_api.id)
        @google_api.roles.should_not include("yahoo-write")
      end

      it "forbids limited admins from assigning an existing role that exists in an api the admin only has partial access to" do
        existing_roles = ApiUserRole.all
        existing_roles.should include("google-extra-write")

        admin_token_auth(@google_admin)
        attributes = FactoryGirl.attributes_for(:google_api, {
          :settings => FactoryGirl.attributes_for(:api_setting, {
            :required_roles => [
              "google-extra-write",
            ],
          }),
        })
        put :update, :format => "json", :id => @google_api.id, :api => attributes

        response.status.should eql(403)
        data = MultiJson.load(response.body)
        data.keys.should eql(["errors"])
        @google_api = Api.find(@google_api.id)
        @google_api.roles.should_not include("google-extra-write")
      end

      it "forbids limited admins from assigning a new role beginning with 'api-umbrella'" do
        admin_token_auth(@google_admin)
        attributes = FactoryGirl.attributes_for(:google_api, {
          :settings => FactoryGirl.attributes_for(:api_setting, {
            :required_roles => [
              "api-umbrella#{rand(999_999)}",
            ],
          }),
        })
        put :update, :format => "json", :id => @google_api.id, :api => attributes

        response.status.should eql(403)
        data = MultiJson.load(response.body)
        data.keys.should eql(["errors"])
        @google_api = Api.find(@google_api.id)
        @google_api.roles.should_not include(attributes[:settings][:required_roles][0])
      end

      it "allows superuser admins to assign a new role beginning with 'api-umbrella'" do
        admin_token_auth(@admin)
        attributes = FactoryGirl.attributes_for(:google_api, {
          :settings => FactoryGirl.attributes_for(:api_setting, {
            :required_roles => [
              "api-umbrella#{rand(999_999)}",
            ],
          }),
        })
        put :update, :format => "json", :id => @google_api.id, :api => attributes

        response.status.should eql(204)
        @google_api = Api.find(@google_api.id)
        @google_api.settings.required_roles.should eql(attributes[:settings][:required_roles])
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
        admin_token_auth(@unauthorized_google_admin)
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
