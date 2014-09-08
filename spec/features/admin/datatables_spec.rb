require 'spec_helper'

describe "datatables", :js => true do
  login_admin

  before(:each) do
    ApiUser.where(:registration_source.ne => "seed").delete_all
    Api.delete_all
  end

  describe "search" do
    it "removes the default label" do
      visit "/admin/#/api_users"
      find(".dataTables_filter").text.should eql("")
    end

    it "uses a placeholder" do
      visit "/admin/#/api_users"
      find(".dataTables_filter input")[:placeholder].should eql("Search...")
    end
  end

  describe "processing" do
    it "displays a spinner on initial load" do
      visit "/admin/#/api_users"
      page.should have_selector(".dataTables_wrapper .blockOverlay")
      page.should have_selector(".dataTables_wrapper .blockMsg .fa-spinner")
      # Waiting for ajax
      page.should_not have_selector(".dataTables_wrapper .blockOverlay")
      page.should_not have_selector(".dataTables_wrapper .blockMsg")
    end

    it "displays a spinner when server side processing" do
      visit "/admin/#/api_users"
      # Waiting for ajax
      page.should_not have_selector(".dataTables_wrapper .blockOverlay")
      page.should_not have_selector(".dataTables_wrapper .blockMsg")
      find("thead tr:first-child").click
      page.should have_selector(".dataTables_wrapper .blockOverlay")
      page.should have_selector(".dataTables_wrapper .blockMsg .fa-spinner")
      # Waiting for ajax
      page.should_not have_selector(".dataTables_wrapper .blockOverlay")
      page.should_not have_selector(".dataTables_wrapper .blockMsg")
    end
  end
end
