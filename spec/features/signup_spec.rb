require "spec_helper"

describe "signup process" do
  context "validation errors" do
    it "still creates an account when submitted from the error page" do
      visit "/signup"

      fill_in "api_user_first_name", :with => "Ambrose"
      fill_in "api_user_last_name", :with => "Burnside"
      fill_in "api_user_email", :with => "ambrose.burnside@example.com"
      if(ApiUser.fields.include?("website"))
        fill_in "api_user_website", :with => "example.com"
      end
      click_button "Signup"

      page.should have_content "Check the box to agree to the terms and conditions"

      check("I have read and agree to the terms and conditions.")
      click_button "Signup"

      page.should have_content(/Your API key for .+ is:/)
    end
  end
end
