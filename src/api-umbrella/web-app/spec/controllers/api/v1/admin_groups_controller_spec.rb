require 'spec_helper'

describe Api::V1::AdminGroupsController do
  before(:each) do
    DatabaseCleaner.clean
  end

  describe "GET index" do
    before(:each) do
      @admin = FactoryGirl.create(:admin)
    end

    describe "admin_usernames" do
      it "returns an array of admin usernames belonging to the group" do
        group = FactoryGirl.create(:admin_group)
        admin_in_group = FactoryGirl.create(:limited_admin, :groups => [
          group,
        ])

        admin_token_auth(@admin)
        get :index, :format => "json"

        data = MultiJson.load(response.body)
        data["data"].length.should eql(1)
        data["data"][0]["admin_usernames"].should eql([admin_in_group.username])
      end

      it "sorts usernames in alphabetical order" do
        group = FactoryGirl.create(:admin_group)
        admin_in_group1 = FactoryGirl.create(:limited_admin, :username => "b", :groups => [
          group,
        ])
        admin_in_group2 = FactoryGirl.create(:limited_admin, :username => "a", :groups => [
          group,
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
    before(:each) do
      @admin = FactoryGirl.create(:admin)
    end

    describe "admins" do
      it "returns metadata for the admins belonging to the group" do
        group = FactoryGirl.create(:admin_group)
        admin_in_group = FactoryGirl.create(:limited_admin, :last_sign_in_at => Time.now, :groups => [
          group,
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
        admin_in_group1 = FactoryGirl.create(:limited_admin, :username => "b", :groups => [
          group,
        ])
        admin_in_group2 = FactoryGirl.create(:limited_admin, :username => "a", :groups => [
          group,
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

  describe "admin permissions" do
    shared_examples "admin permitted" do
      describe "GET index" do
        it "includes the group in the results" do
          record = FactoryGirl.create(@factory)
          admin_token_auth(@admin)

          get :index, :format => "json"

          response.status.should eql(200)
          data = MultiJson.load(response.body)
          record_ids = data["data"].map { |r| r["id"] }
          record_ids.should include(record.id)
        end
      end

      describe "GET show" do
        it "permits access" do
          record = FactoryGirl.create(@factory)
          admin_token_auth(@admin)

          get :show, :format => "json", :id => record.id

          response.status.should eql(200)
          data = MultiJson.load(response.body)
          data.keys.should eql(["admin_group"])
        end
      end

      describe "POST create" do
        it "permits access" do
          attributes = FactoryGirl.build(@factory).serializable_hash
          admin_token_auth(@admin)

          expect do
            post :create, :format => "json", :admin_group => attributes

            response.status.should eql(201)
            data = MultiJson.load(response.body)
            data["admin_group"]["name"].should_not eql(nil)
            data["admin_group"]["name"].should eql(attributes["name"])
          end.to change { AdminGroup.count }.by(1)
        end
      end

      describe "PUT update" do
        it "permits access" do
          record = FactoryGirl.create(@factory)
          admin_token_auth(@admin)

          attributes = record.serializable_hash
          attributes["name"] += rand(999_999).to_s
          put :update, :format => "json", :id => record.id, :admin_group => attributes

          response.status.should eql(204)
          record = AdminGroup.find(record.id)
          record.name.should_not eql(nil)
          record.name.should eql(attributes["name"])
        end
      end

      describe "DELETE destroy" do
        it "permits access" do
          record = FactoryGirl.create(@factory)
          admin_token_auth(@admin)

          expect do
            delete :destroy, :format => "json", :id => record.id
            response.status.should eql(204)
          end.to change { AdminGroup.count }.by(-1)
        end
      end
    end

    shared_examples "admin forbidden" do
      describe "GET index" do
        it "excludes the group in the results" do
          record = FactoryGirl.create(@factory)
          admin_token_auth(@admin)

          get :index, :format => "json"

          response.status.should eql(200)
          data = MultiJson.load(response.body)
          record_ids = data["data"].map { |r| r["id"] }
          record_ids.should_not include(record.id)
        end
      end

      describe "GET show" do
        it "forbids access" do
          record = FactoryGirl.create(@factory)
          admin_token_auth(@admin)

          get :show, :format => "json", :id => record.id

          response.status.should eql(403)
          data = MultiJson.load(response.body)
          data.keys.should eql(["errors"])
        end
      end

      describe "POST create" do
        it "forbids access" do
          attributes = FactoryGirl.build(@factory).serializable_hash
          admin_token_auth(@admin)

          expect do
            post :create, :format => "json", :admin_group => attributes

            response.status.should eql(403)
            data = MultiJson.load(response.body)
            data.keys.should eql(["errors"])
          end.to change { AdminGroup.count }.by(0)
        end
      end

      describe "PUT update" do
        it "forbids access" do
          record = FactoryGirl.create(@factory)
          admin_token_auth(@admin)

          attributes = record.serializable_hash
          attributes["name"] += rand(999_999).to_s
          put :update, :format => "json", :id => record.id, :admin_group => attributes

          response.status.should eql(403)
          data = MultiJson.load(response.body)
          data.keys.should eql(["errors"])

          record = AdminGroup.find(record.id)
          record.name.should_not eql(nil)
          record.name.should_not eql(attributes["name"])
        end
      end

      describe "DELETE destroy" do
        it "forbids access" do
          record = FactoryGirl.create(@factory)
          admin_token_auth(@admin)

          expect do
            delete :destroy, :format => "json", :id => record.id

            response.status.should eql(403)
            data = MultiJson.load(response.body)
            data.keys.should eql(["errors"])
          end.to change { AdminGroup.count }.by(0)
        end
      end
    end

    describe "localhost/google* group (single scope)" do
      before(:each) do
        @google_api_scope = ApiScope.find_or_create_by_instance!(FactoryGirl.build(:google_api_scope))
        @factory = :google_admin_group
      end

      it_behaves_like "admin permissions", :required_permissions => ["admin_manage"]
    end

    describe "localhost/google* and localhost/yahoo* group (multi scope)" do
      before(:each) do
        @google_api_scope = ApiScope.find_or_create_by_instance!(FactoryGirl.build(:google_api_scope))
        @yahoo_api_scope = ApiScope.find_or_create_by_instance!(FactoryGirl.build(:yahoo_api_scope))
        @factory = :google_and_yahoo_multi_scope_admin_group
      end

      describe "superuser" do
        before(:each) do
          @admin = FactoryGirl.create(:admin)
        end
        it_behaves_like "admin permitted"
      end

      describe "localhost/google* and localhost/yahoo* full admin" do
        before(:each) do
          @admin = FactoryGirl.create(:limited_admin, :groups => [
            FactoryGirl.create(:admin_group, :api_scopes => [
              @google_api_scope,
              @yahoo_api_scope,
            ]),
          ])
        end
        it_behaves_like "admin permitted"
      end

      describe "localhost/google* full admin" do
        before(:each) do
          @admin = FactoryGirl.create(:limited_admin, :groups => [
            FactoryGirl.create(:admin_group, :api_scopes => [
              @google_api_scope,
            ]),
          ])
        end
        it_behaves_like "admin forbidden"
      end

      describe "localhost/yahoo* full admin" do
        before(:each) do
          @admin = FactoryGirl.create(:limited_admin, :groups => [
            FactoryGirl.create(:admin_group, :api_scopes => [
              @yahoo_api_scope,
            ]),
          ])
        end
        it_behaves_like "admin forbidden"
      end
    end

    it "prevents limited admins from updating its own group to contain scopes outside the current permissions" do
      record = FactoryGirl.create(:google_admin_group)
      yahoo_api_scope = ApiScope.find_or_create_by_instance!(FactoryGirl.build(:yahoo_api_scope))

      admin = FactoryGirl.create(:limited_admin, :groups => [record])
      admin_token_auth(admin)

      attributes = record.serializable_hash
      attributes["api_scope_ids"] << yahoo_api_scope.id
      put :update, :format => "json", :id => record.id, :admin_group => attributes

      response.status.should eql(403)
      data = MultiJson.load(response.body)
      data.keys.should eql(["errors"])

      record = AdminGroup.find(record.id)
      record.api_scope_ids.length.should eql(1)
    end

    it "prevents limited admins from updating forbidden groups to only contain scopes the admin does have permissions to" do
      record = FactoryGirl.create(:yahoo_admin_group)
      yahoo_api_scope = ApiScope.find_or_create_by_instance!(FactoryGirl.build(:yahoo_api_scope))
      google_api_scope = ApiScope.find_or_create_by_instance!(FactoryGirl.build(:google_api_scope))

      admin = FactoryGirl.create(:google_admin)
      admin_token_auth(admin)

      attributes = record.serializable_hash
      attributes["api_scope_ids"] = google_api_scope.id
      put :update, :format => "json", :id => record.id, :admin_group => attributes

      response.status.should eql(403)
      data = MultiJson.load(response.body)
      data.keys.should eql(["errors"])

      record = AdminGroup.find(record.id)
      record.api_scope_ids.should eql([yahoo_api_scope.id])
    end
  end
end
