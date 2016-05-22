require 'spec_helper'

describe Api::V1::AdminsController do
  before(:each) do
    DatabaseCleaner.clean
  end

  shared_examples "admin save permissions" do |method, action|
    it "return validation error if account has no groups and isn't a superuser" do
      attributes = FactoryGirl.build(:admin, {
        :superuser => false,
        :groups => [],
      }).serializable_hash

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
    before(:each) do
      @admin = FactoryGirl.create(:admin)
    end

    it "paginates results" do
      FactoryGirl.create_list(:admin, 3)

      admin_token_auth(@admin)
      get :index, :format => "json", :length => 2

      admin_count = Admin.count
      admin_count.should be > 2

      data = MultiJson.load(response.body)
      data["recordsTotal"].should eql(admin_count)
      data["recordsFiltered"].should eql(admin_count)
      data["data"].length.should eql(2)
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

  describe "validations" do
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
          data.keys.should eql(["admin"])
        end
      end

      describe "POST create" do
        it "permits access" do
          attributes = FactoryGirl.build(@factory).serializable_hash
          admin_token_auth(@admin)

          expect do
            post :create, :format => "json", :admin => attributes

            response.status.should eql(201)
            data = MultiJson.load(response.body)
            data["admin"]["username"].should_not eql(nil)
            data["admin"]["username"].should eql(attributes["username"])
          end.to change { Admin.count }.by(1)
        end
      end

      describe "PUT update" do
        it "permits access" do
          record = FactoryGirl.create(@factory)
          admin_token_auth(@admin)

          attributes = record.serializable_hash
          attributes["username"] += rand(999_999).to_s
          put :update, :format => "json", :id => record.id, :admin => attributes

          response.status.should eql(200)
          data = MultiJson.load(response.body)
          data["admin"]["username"].should_not eql(nil)
          data["admin"]["username"].should eql(attributes["username"])

          record = Admin.find(record.id)
          record.username.should_not eql(nil)
          record.username.should eql(attributes["username"])
        end
      end

      describe "DELETE destroy" do
        it "permits access" do
          record = FactoryGirl.create(@factory)
          admin_token_auth(@admin)

          expect do
            delete :destroy, :format => "json", :id => record.id
            response.status.should eql(204)
          end.to change { Admin.count }.by(-1)
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
            post :create, :format => "json", :admin => attributes

            response.status.should eql(403)
            data = MultiJson.load(response.body)
            data.keys.should eql(["errors"])
          end.to change { Admin.count }.by(0)
        end
      end

      describe "PUT update" do
        it "forbids access" do
          record = FactoryGirl.create(@factory)
          admin_token_auth(@admin)

          attributes = record.serializable_hash
          attributes["username"] += rand(999_999).to_s
          put :update, :format => "json", :id => record.id, :admin => attributes

          response.status.should eql(403)
          data = MultiJson.load(response.body)
          data.keys.should eql(["errors"])

          record = Admin.find(record.id)
          record.username.should_not eql(nil)
          record.username.should_not eql(attributes["username"])
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
          end.to change { Admin.count }.by(0)
        end
      end
    end

    describe "localhost/google* admin (single group, single scope)" do
      before(:each) do
        @factory = :google_admin
      end

      it_behaves_like "admin permissions", :required_permissions => ["admin_manage"]
    end

    describe "localhost/google* and localhost/yahoo* admin (multi group, multi scope)" do
      before(:each) do
        @google_api_scope = ApiScope.find_or_create_by_instance!(FactoryGirl.build(:google_api_scope))
        @yahoo_api_scope = ApiScope.find_or_create_by_instance!(FactoryGirl.build(:yahoo_api_scope))
        @factory = :google_and_yahoo_multi_group_admin
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

    describe "localhost/google* and localhost/yahoo* admin (single group, multi scope)" do
      before(:each) do
        @google_api_scope = ApiScope.find_or_create_by_instance!(FactoryGirl.build(:google_api_scope))
        @yahoo_api_scope = ApiScope.find_or_create_by_instance!(FactoryGirl.build(:yahoo_api_scope))
        @factory = :google_and_yahoo_single_group_admin
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

    describe "superuser admin" do
      before(:each) do
        @factory = :admin
      end

      describe "superuser" do
        before(:each) do
          @admin = FactoryGirl.create(:admin)
        end
        it_behaves_like "admin permitted"
      end

      describe "localhost/* full admin" do
        before(:each) do
          @admin = FactoryGirl.create(:limited_admin, :groups => [
            FactoryGirl.create(:localhost_root_admin_group)
          ])
        end
        it_behaves_like "admin forbidden"
      end

      describe "localhost/google* full admin" do
        before(:each) do
          @admin = FactoryGirl.create(:google_admin)
        end
        it_behaves_like "admin forbidden"
      end
    end

    it "prevents limited admins from adding the superuser attribute on an existing limited admin account" do
      record = FactoryGirl.create(:limited_admin)

      admin = FactoryGirl.create(:limited_admin)
      admin_token_auth(admin)

      attributes = record.serializable_hash
      attributes["superuser"] = "1"
      put :update, :format => "json", :id => record.id, :admin => attributes

      response.status.should eql(403)
      record = Admin.find(record.id)
      record.superuser.should eql(false)
    end

    it "prevents limited admins from adding the superuser attribute on its own account" do
      record = FactoryGirl.create(:limited_admin)

      admin_token_auth(record)

      attributes = record.serializable_hash
      attributes["superuser"] = "1"
      put :update, :format => "json", :id => record.id, :admin => attributes

      response.status.should eql(403)
      record = Admin.find(record.id)
      record.superuser.should eql(false)
    end

    it "prevents limited admins from removing the superuser attribute on an existing superuser admin account" do
      record = FactoryGirl.create(:limited_admin, :superuser => true)

      admin = FactoryGirl.create(:limited_admin)
      admin_token_auth(admin)

      attributes = record.serializable_hash
      attributes["superuser"] = "0"
      put :update, :format => "json", :id => record.id, :admin => attributes

      response.status.should eql(403)
      record = Admin.find(record.id)
      record.superuser.should eql(true)
    end

    it "prevents limited admins from updating forbidden admins to only contain groups the admin does have permissions to" do
      google_admin_group = FactoryGirl.create(:google_admin_group)
      yahoo_admin_group = FactoryGirl.create(:yahoo_admin_group)
      record = FactoryGirl.create(:limited_admin, :groups => [yahoo_admin_group])

      admin = FactoryGirl.create(:google_admin)
      admin_token_auth(admin)

      attributes = record.serializable_hash
      attributes["group_ids"] = google_admin_group.id
      put :update, :format => "json", :id => record.id, :admin => attributes

      response.status.should eql(403)
      data = MultiJson.load(response.body)
      data.keys.should eql(["errors"])

      record = Admin.find(record.id)
      record.group_ids.should eql([yahoo_admin_group.id])
    end

    it "permits superuser admins from adding the superuser attribute on an existing limited admin account" do
      record = FactoryGirl.create(:limited_admin)

      admin = FactoryGirl.create(:admin)
      admin_token_auth(admin)

      attributes = record.serializable_hash
      attributes["superuser"] = "1"
      put :update, :format => "json", :id => record.id, :admin => attributes

      response.status.should eql(200)
      record = Admin.find(record.id)
      record.superuser.should eql(true)
    end

    it "permits superuser admins from removing the superuser attribute on an existing superuser admin account" do
      record = FactoryGirl.create(:limited_admin, :superuser => true)

      admin = FactoryGirl.create(:admin)
      admin_token_auth(admin)

      attributes = record.serializable_hash
      attributes["superuser"] = "0"
      put :update, :format => "json", :id => record.id, :admin => attributes

      response.status.should eql(200)
      record = Admin.find(record.id)
      record.superuser.should eql(false)
    end
  end
end
