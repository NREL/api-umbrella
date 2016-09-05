require "rails_helper"

RSpec.describe "datatables", :js => true do
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
      # We can't reliably check for the spinner on page load (it might
      # disappear too quickly), so just ensure it eventualy disappears.
      page.should_not have_selector(".dataTables_wrapper .blockOverlay")
      page.should_not have_selector(".dataTables_wrapper .blockMsg")
    end

    it "displays a spinner when server side processing" do
      visit "/admin/#/api_users"

      # Slow down ajax queries so we can reliably have enough time to make sure
      # that clicking a header triggers a server-side refresh which in turn
      # should briefly show the spinner.
      delay_all_ajax_calls
      find("thead tr:first-child").click
      page.should have_selector(".dataTables_wrapper .blockMsg .fa-spinner")

      # Ensure that the spinner eventually goes away after things load.
      page.should_not have_selector(".dataTables_wrapper .blockOverlay")
      page.should_not have_selector(".dataTables_wrapper .blockMsg")
    end
  end
end
