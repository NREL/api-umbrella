require "spec_helper"

describe Api::V1::ApiScopesController do
  before(:each) do
    DatabaseCleaner.clean
  end

  describe "admin permissions" do
    shared_examples "admin permitted" do
      describe "GET index" do
        it "includes the scope in the results" do
          record = ApiScope.find_or_create_by_instance!(FactoryGirl.build(@factory))
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
          record = ApiScope.find_or_create_by_instance!(FactoryGirl.build(@factory))
          admin_token_auth(@admin)

          get :show, :format => "json", :id => record.id

          response.status.should eql(200)
          data = MultiJson.load(response.body)
          data.keys.should eql(["api_scope"])
        end
      end

      describe "POST create" do
        it "permits access" do
          attributes = FactoryGirl.attributes_for(@factory).stringify_keys
          admin_token_auth(@admin)

          expect do
            post :create, :format => "json", :api_scope => attributes

            # Validation errors may occur on some of the create tests, since we
            # can't create duplicate records with the same hostname and prefix.
            # This is expected to happen in some of the tests where we have to
            # create a scope for the admin group we're authenticating as prior
            # to this create attempt.
            if(response.status == 422)
              response.status.should eql(422)
              data = MultiJson.load(response.body)
              data.should eql("errors" => { "path_prefix" => ["is already taken"] })

              # Add something extra to the path prefix, since create sub-scopes
              # within an existing prefix should be permitted.
              @path_prefix_increment ||= 0
              @path_prefix_increment += 1
              attributes["path_prefix"] += @path_prefix_increment.to_s
              post :create, :format => "json", :api_scope => attributes
            end

            response.status.should eql(201)
            data = MultiJson.load(response.body)
            data["api_scope"]["name"].should_not eql(nil)
            data["api_scope"]["name"].should eql(attributes["name"])
          end.to change { ApiScope.count }.by(1)
        end
      end

      describe "PUT update" do
        it "permits access" do
          record = ApiScope.find_or_create_by_instance!(FactoryGirl.build(@factory))
          admin_token_auth(@admin)

          attributes = record.serializable_hash
          attributes["name"] += rand(999_999).to_s
          put :update, :format => "json", :id => record.id, :api_scope => attributes

          response.status.should eql(204)
          record = ApiScope.find(record.id)
          record.name.should_not eql(nil)
          record.name.should eql(attributes["name"])
        end
      end

      describe "DELETE destroy" do
        it "permits access" do
          record = ApiScope.find_or_create_by_instance!(FactoryGirl.build(@factory))
          admin_token_auth(@admin)

          expect do
            delete :destroy, :format => "json", :id => record.id
            response.status.should eql(204)
          end.to change { ApiScope.count }.by(-1)
        end
      end
    end

    shared_examples "admin forbidden" do
      describe "GET index" do
        it "excludes the group in the results" do
          record = ApiScope.find_or_create_by_instance!(FactoryGirl.build(@factory))
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
          record = ApiScope.find_or_create_by_instance!(FactoryGirl.build(@factory))
          admin_token_auth(@admin)

          get :show, :format => "json", :id => record.id

          response.status.should eql(403)
          data = MultiJson.load(response.body)
          data.keys.should eql(["errors"])
        end
      end

      describe "POST create" do
        it "forbids access" do
          attributes = FactoryGirl.attributes_for(@factory).stringify_keys
          admin_token_auth(@admin)

          expect do
            post :create, :format => "json", :api_scope => attributes

            response.status.should eql(403)
            data = MultiJson.load(response.body)
            data.keys.should eql(["errors"])
          end.to change { ApiScope.count }.by(0)
        end
      end

      describe "PUT update" do
        it "forbids access" do
          record = ApiScope.find_or_create_by_instance!(FactoryGirl.build(@factory))
          admin_token_auth(@admin)

          attributes = record.serializable_hash
          attributes["name"] += rand(999_999).to_s
          put :update, :format => "json", :id => record.id, :api_scope => attributes

          response.status.should eql(403)
          data = MultiJson.load(response.body)
          data.keys.should eql(["errors"])

          record = ApiScope.find(record.id)
          record.name.should_not eql(nil)
          record.name.should_not eql(attributes["name"])
        end
      end

      describe "DELETE destroy" do
        it "forbids access" do
          record = ApiScope.find_or_create_by_instance!(FactoryGirl.build(@factory))
          admin_token_auth(@admin)

          expect do
            delete :destroy, :format => "json", :id => record.id

            response.status.should eql(403)
            data = MultiJson.load(response.body)
            data.keys.should eql(["errors"])
          end.to change { ApiScope.count }.by(0)
        end
      end
    end

    describe "localhost/google* scope" do
      before(:each) do
        @factory = :google_api_scope
      end

      it_behaves_like "admin permissions", :required_permissions => ["admin_manage"]
    end

    it "prevents limited admins from updating forbidden scopes to only use scopes the admin does have permissions to" do
      record = FactoryGirl.create(:yahoo_api_scope)

      admin = FactoryGirl.create(:google_admin)
      admin_token_auth(admin)

      attributes = record.serializable_hash
      attributes["path_prefix"] = "/google/#{rand(999_999)}"
      put :update, :format => "json", :id => record.id, :api_scope => attributes

      response.status.should eql(403)
      data = MultiJson.load(response.body)
      data.keys.should eql(["errors"])

      record = ApiScope.find(record.id)
      record.path_prefix.should eql("/yahoo")
    end
  end
end
