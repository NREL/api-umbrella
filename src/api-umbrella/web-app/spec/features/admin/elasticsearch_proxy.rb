require "rails_helper"

RSpec.describe "elasticsearch proxy", :js => true do
  shared_examples "allowed access" do
  end

  shared_examples "denied access" do
  end

  describe "not logged in" do
    it "redirects to the login page when accessing the root elasticsearch page" do
      visit "/admin/elasticsearch"
      page.current_url.should end_with("/admin/login")
      page.should have_content("You need to sign in")
      page.should_not have_content('"lucene_version"')
    end

    it "redirects to the login page when trying to perform a basic elasticsearch query" do
      visit "/admin/elasticsearch/_search"
      page.current_url.should end_with("/admin/login")
      page.should have_content("You need to sign in")
      page.should_not have_content('"hits"')
    end
  end

  describe "logged in as limited admin" do
    let(:current_admin) { FactoryGirl.create(:limited_admin) }
    login_admin

    it "returns a not found error when accessing the root elasticsearch page" do
      visit "/admin/elasticsearch"
      page.status_code.should eql(404)
      page.should_not have_content('"lucene_version"')
    end

    it "returns a not found error when trying to perform a basic elasticsearch query" do
      visit "/admin/elasticsearch/_search"
      page.status_code.should eql(404)
      page.should_not have_content('"hits"')
    end
  end

  describe "logged in as superuser" do
    login_admin

    it "returns the root elasticsearch status page" do
      visit "/admin/elasticsearch"
      page.status_code.should eql(200)
      page.should have_content('"lucene_version"')
    end

    it "performs a basic elasticsearch query" do
      visit "/admin/elasticsearch/_search"
      page.status_code.should eql(200)
      page.should have_content('"hits"')
    end

    it "rewrites meta redirects returned by elasticsearch" do
      visit "/admin/elasticsearch/_plugin/foobar"
      page.body.should include("URL=/admin/elasticsearch/_plugin/foobar/")
    end
  end
end
