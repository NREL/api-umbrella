require 'spec_helper'

describe "admins form", :js => true do
  describe "superuser is logged in" do
    login_admin

    it "shows the superuser checkbox" do
      visit "/admin/#/admins/new"

      page.should have_content("Username")
      page.should have_content("Superuser")
    end
  end

  describe "limited admin is logged in" do
    let(:current_admin) { FactoryGirl.create(:limited_admin) }
    login_admin

    it "hides the superuser checkbox" do
      visit "/admin/#/admins/new"

      page.should have_content("Username")
      page.should_not have_content("Superuser")
    end
  end

  describe "group checkboxes" do
    login_admin

    before(:all) do
      @group1 = FactoryGirl.create(:admin_group)
      @group2 = FactoryGirl.create(:admin_group)
      @group3 = FactoryGirl.create(:admin_group)
    end

    it "adds groups to the admin account when checkboxes are checked" do
      admin = FactoryGirl.create(:admin)
      admin.group_ids.should eql([])

      visit "/admin/#/admins/#{admin.id}/edit"

      check @group1.name
      check @group3.name

      click_button("Save")

      page.should have_content("Successfully saved the admin")

      admin = Admin.find(admin.id)
      admin.group_ids.sort.should eql([@group1.id, @group3.id].sort)
    end

    it "removes groups from the admin account when checkboxes are unchecked" do
      admin = FactoryGirl.create(:admin, :groups => [@group1, @group2])
      admin.group_ids.sort.should eql([@group1.id, @group2.id].sort)

      visit "/admin/#/admins/#{admin.id}/edit"

      uncheck @group1.name
      uncheck @group2.name
      check @group3.name

      click_button("Save")

      page.should have_content("Successfully saved the admin")

      admin = Admin.find(admin.id)
      admin.group_ids.sort.should eql([@group3.id].sort)
    end
  end
end
