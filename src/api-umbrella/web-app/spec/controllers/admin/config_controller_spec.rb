require 'spec_helper'

describe Admin::ConfigController do
  before(:all) do
    @admin = FactoryGirl.create(:admin)
    @google_admin = FactoryGirl.create(:limited_admin, :groups => [FactoryGirl.create(:google_admin_group)])
  end

  before(:each) do
    Api.delete_all
    ConfigVersion.delete_all
  end

  describe "GET import_export" do
    it "allows superuser admins" do
      admin_login_auth(@admin)
      get :import_export

      response.status.should eql(200)
    end

    it "rejects limited admins" do
      expect do
        admin_login_auth(@google_admin)
        get :import_export
      end.to raise_error(Pundit::NotAuthorizedError)
    end
  end

  describe "GET export" do
    it "allows superuser admins" do
      admin_login_auth(@admin)
      get :export, :format => "yaml"

      response.status.should eql(200)
    end

    it "rejects limited admins" do
      expect do
        admin_login_auth(@google_admin)
        get :export, :format => "yaml"
      end.to raise_error(Pundit::NotAuthorizedError)
    end
  end

  describe "POST import_preview" do
    it "allows superuser admins" do
      admin_login_auth(@admin)
      post :import_preview, :uploaded => "apis: []"

      response.status.should eql(200)
    end

    it "rejects limited admins" do
      expect do
        admin_login_auth(@google_admin)
        post :import_preview, :uploaded => "apis: []"
      end.to raise_error(Pundit::NotAuthorizedError)
    end
  end

  describe "POST import" do
    it "allows superuser admins" do
      admin_login_auth(@admin)
      post :import, :uploaded => "apis: []"

      response.status.should eql(302)
    end

    it "rejects limited admins" do
      expect do
        admin_login_auth(@google_admin)
        post :import, :uploaded => "apis: []"
      end.to raise_error(Pundit::NotAuthorizedError)
    end
  end
end
