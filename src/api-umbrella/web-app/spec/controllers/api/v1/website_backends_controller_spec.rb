require "spec_helper"

describe Api::V1::WebsiteBackendsController do
  before(:each) do
    DatabaseCleaner.clean
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
          data.keys.should eql(["website_backend"])
        end
      end

      describe "POST create" do
        it "permits access" do
          attributes = FactoryGirl.attributes_for(@factory).stringify_keys
          admin_token_auth(@admin)

          expect do
            post :create, :format => "json", :website_backend => attributes

            response.status.should eql(201)
            data = MultiJson.load(response.body)
            data["website_backend"]["server_host"].should_not eql(nil)
            data["website_backend"]["server_host"].should eql(attributes["server_host"])
          end.to change { WebsiteBackend.count }.by(1)
        end
      end

      describe "PUT update" do
        it "permits access" do
          record = FactoryGirl.create(@factory)
          admin_token_auth(@admin)

          attributes = record.serializable_hash
          attributes["server_host"] += rand(999_999).to_s
          put :update, :format => "json", :id => record.id, :website_backend => attributes

          response.status.should eql(204)
          record = WebsiteBackend.find(record.id)
          record.server_host.should_not eql(nil)
          record.server_host.should eql(attributes["server_host"])
        end
      end

      describe "DELETE destroy" do
        it "permits access" do
          record = FactoryGirl.create(@factory)
          admin_token_auth(@admin)

          expect do
            delete :destroy, :format => "json", :id => record.id
            response.status.should eql(204)
          end.to change { WebsiteBackend.count }.by(-1)
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
          attributes = FactoryGirl.attributes_for(@factory).stringify_keys
          admin_token_auth(@admin)

          expect do
            post :create, :format => "json", :website_backend => attributes

            response.status.should eql(403)
            data = MultiJson.load(response.body)
            data.keys.should eql(["errors"])
          end.to change { WebsiteBackend.count }.by(0)
        end
      end

      describe "PUT update" do
        it "forbids access" do
          record = FactoryGirl.create(@factory)
          admin_token_auth(@admin)

          attributes = record.serializable_hash
          attributes["server_host"] += rand(999_999).to_s
          put :update, :format => "json", :id => record.id, :website_backend => attributes

          response.status.should eql(403)
          data = MultiJson.load(response.body)
          data.keys.should eql(["errors"])

          record = WebsiteBackend.find(record.id)
          record.server_host.should_not eql(nil)
          record.server_host.should_not eql(attributes["server_host"])
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
          end.to change { WebsiteBackend.count }.by(0)
        end
      end
    end

    describe "localhost website backend" do
      before(:each) do
        @factory = :website_backend
      end

      it_behaves_like "admin permissions", :required_permissions => ["backend_manage"], :root_required => true
    end

    it "prevents limited admins from updating forbidden website backends to use a host the admin does have permissions to" do
      record = FactoryGirl.create(:website_backend, :frontend_host => "example.com")

      admin = FactoryGirl.create(:localhost_root_admin)
      admin_token_auth(admin)

      attributes = record.serializable_hash
      attributes["frontend_host"] = "localhost"
      put :update, :format => "json", :id => record.id, :website_backend => attributes

      response.status.should eql(403)
      data = MultiJson.load(response.body)
      data.keys.should eql(["errors"])

      record = WebsiteBackend.find(record.id)
      record.frontend_host.should eql("example.com")
    end
  end
end
