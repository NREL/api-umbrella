require 'spec_helper'

describe AccountsController do
  render_views

  before(:all) do
    ApiUser.delete_all
  end

  describe "#new" do
    it "contains a blank form" do
      get :new
      response.body.should have_form(account_path, "post") do
        with_text_field "api_user[first_name]"
      end
    end

    it "uses i18n labels" do
      get :new
      response.body.should have_tag("label", :text => /How will you use the APIs\?\s*\(optional\)/)
    end
  end

  describe "#create" do
    context "with valid attributes" do
      context "new user" do
        it "creates a new record in the database" do
          expect do
            post :create, :api_user => FactoryGirl.attributes_for(:api_user)
          end.to change { ApiUser.count }.by(1)
        end

        it "renders a page with their new API key" do
          post :create, :api_user => FactoryGirl.attributes_for(:api_user)
          response.body.should =~ /api_key=/
        end

        it "defaults" do
          post :create, :api_user => FactoryGirl.attributes_for(:api_user)
          user = ApiUser.desc(:created_at).last
          user.registration_source.should eql("web")
        end
      end

      context "existing user" do
        before(:all) do
          pending("Not applicable with website field disabled") unless(ApiUser.fields.include?("website"))
          @existing_user = FactoryGirl.create(:api_user, :email => "existing.user@example.com")
        end

        it "does not create a new record in the database" do
          expect do
            post :create, :api_user => FactoryGirl.attributes_for(:api_user).merge(:email => @existing_user.email)
          end.to_not change { ApiUser.count }
        end

        it "renders a page with their existing API key" do
          post :create, :api_user => FactoryGirl.attributes_for(:api_user).merge(:email => @existing_user.email)
          response.body.should =~ /api_key=#{@existing_user.api_key}/
        end
      end
    end

    context "with invalid attributes" do
      it "does not create a new record in the database" do
        expect do
          post :create, :api_user => FactoryGirl.attributes_for(:invalid_api_user)
        end.to_not change { ApiUser.count }
      end

      it "renders the form again" do
        post :create, :api_user => FactoryGirl.attributes_for(:invalid_api_user)
        response.should render_template(:new)
      end
    end
  end
end
