require 'spec_helper'

describe Admin::Admins::OmniauthCallbacksController do
  before(:all) do
    Admin.delete_all
    @valid_admin = FactoryGirl.create(:admin, :username => "test@example.com")
    @case_insensitive_admin = FactoryGirl.create(:admin, :username => "HELLO@example.com")
    @unverified_admin = FactoryGirl.create(:admin, :username => "unverified@example.com")
  end

  before(:each) do
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:cas] = nil
    OmniAuth.config.mock_auth[:developer] = nil
    OmniAuth.config.mock_auth[:facebook] = nil
    OmniAuth.config.mock_auth[:github] = nil
    OmniAuth.config.mock_auth[:google_oauth2] = nil
    OmniAuth.config.mock_auth[:myusa] = nil
    OmniAuth.config.mock_auth[:persona] = nil
    OmniAuth.config.mock_auth[:twitter] = nil

    request.env["devise.mapping"] = Devise.mappings[:admin]
  end

  shared_examples "omniauth login" do |provider|
    it "allows valid admins" do
      request.env["omniauth.auth"] = @valid_omniauth

      get(provider)
      session["warden.user.admin.key"].should be_kind_of(Array)
      session["warden.user.admin.key"][0].should be_kind_of(Array)
      admin_id = session["warden.user.admin.key"][0][0]
      admin_id.should eql(@valid_admin.id)
    end

    it "treats the e-mail for login case insensitively" do
      request.env["omniauth.auth"] = @case_insensitive_omniauth

      get(provider)
      session["warden.user.admin.key"].should be_kind_of(Array)
      session["warden.user.admin.key"][0].should be_kind_of(Array)
      admin_id = session["warden.user.admin.key"][0][0]
      admin_id.should eql(@case_insensitive_admin.id)
    end

    it "denies non-existent admins" do
      OmniAuth.config.mock_auth[provider] = @nonexistent_omniauth
      request.env["omniauth.auth"] = OmniAuth.config.mock_auth[provider]

      get(provider)
      session["warden.user.admin.key"].should eql(nil)
    end
  end

  shared_examples "omniauth verified e-mail login" do |provider|
    it "denies unverified e-mail addresses" do
      OmniAuth.config.mock_auth[provider] = @unverified_omniauth
      request.env["omniauth.auth"] = OmniAuth.config.mock_auth[provider]

      get(provider)
      session["warden.user.admin.key"].should eql(nil)
    end
  end

  describe "cas" do
    before(:all) do
      @valid_omniauth = OmniAuth::AuthHash.new({
        :provider => "cas",
        :uid => @valid_admin.username,
      })

      @case_insensitive_omniauth = @valid_omniauth.deep_dup
      @case_insensitive_omniauth[:uid] = "Hello@ExamplE.Com"

      @nonexistent_omniauth = @valid_omniauth.deep_dup
      @nonexistent_omniauth[:uid] = "bad@example.com"
    end

    it_behaves_like "omniauth login", :cas
  end

  describe "facebook" do
    before(:all) do
      @valid_omniauth = OmniAuth::AuthHash.new({
        :provider => "facebook",
        :uid => "12345",
        :info => {
          :email => @valid_admin.username,
          :verified => true,
        },
      })

      @case_insensitive_omniauth = @valid_omniauth.deep_dup
      @case_insensitive_omniauth[:info][:email] = "Hello@ExamplE.Com"

      @nonexistent_omniauth = @valid_omniauth.deep_dup
      @nonexistent_omniauth[:info][:email] = "bad@example.com"

      @unverified_omniauth = @valid_omniauth.deep_dup
      @unverified_omniauth[:info][:verified] = false
    end

    it_behaves_like "omniauth login", :facebook
    it_behaves_like "omniauth verified e-mail login", :facebook
  end

  describe "github" do
    before(:all) do
      @valid_omniauth = OmniAuth::AuthHash.new({
        :provider => "github",
        :uid => "12345",
        :info => {
          :email => @valid_admin.username,
          :email_verified => true,
        },
      })

      @case_insensitive_omniauth = @valid_omniauth.deep_dup
      @case_insensitive_omniauth[:info][:email] = "Hello@ExamplE.Com"

      @nonexistent_omniauth = @valid_omniauth.deep_dup
      @nonexistent_omniauth[:info][:email] = "bad@example.com"

      @unverified_omniauth = @valid_omniauth.deep_dup
      @unverified_omniauth[:info][:email_verified] = false
    end

    it_behaves_like "omniauth login", :github
    it_behaves_like "omniauth verified e-mail login", :github
  end

  describe "google_oauth2" do
    before(:all) do
      @valid_omniauth = OmniAuth::AuthHash.new({
        :provider => "google_oauth2",
        :uid => "12345",
        :info => {
          :email => @valid_admin.username,
        },
        :extra => {
          :raw_info => {
            :email_verified => true,
          },
        },
      })

      @case_insensitive_omniauth = @valid_omniauth.deep_dup
      @case_insensitive_omniauth[:info][:email] = "Hello@ExamplE.Com"

      @nonexistent_omniauth = @valid_omniauth.deep_dup
      @nonexistent_omniauth[:info][:email] = "bad@example.com"

      @unverified_omniauth = @valid_omniauth.deep_dup
      @unverified_omniauth[:extra][:raw_info][:email_verified] = false
    end

    it_behaves_like "omniauth login", :google_oauth2
    it_behaves_like "omniauth verified e-mail login", :google_oauth2
  end

  describe "myusa" do
    before(:all) do
      @valid_omniauth = OmniAuth::AuthHash.new({
        :provider => "myusa",
        :uid => "12345",
        :info => {
          :email => @valid_admin.username,
        },
      })

      @case_insensitive_omniauth = @valid_omniauth.deep_dup
      @case_insensitive_omniauth[:info][:email] = "Hello@ExamplE.Com"

      @nonexistent_omniauth = @valid_omniauth.deep_dup
      @nonexistent_omniauth[:info][:email] = "bad@example.com"
    end

    it_behaves_like "omniauth login", :myusa
  end

  describe "persona" do
    before(:all) do
      @valid_omniauth = OmniAuth::AuthHash.new({
        :provider => "persona",
        :uid => "12345",
        :info => {
          :email => @valid_admin.username,
        },
      })

      @case_insensitive_omniauth = @valid_omniauth.deep_dup
      @case_insensitive_omniauth[:info][:email] = "Hello@ExamplE.Com"

      @nonexistent_omniauth = @valid_omniauth.deep_dup
      @nonexistent_omniauth[:info][:email] = "bad@example.com"
    end

    it_behaves_like "omniauth login", :persona
  end
end
