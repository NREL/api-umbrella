require 'spec_helper'

describe "apis", :js => true do
  login_admin

  before(:each) do
    Api.delete_all
  end

  describe "reordering" do
    before(:each) do
      FactoryGirl.create(:api, :name => "API A", :sort_order => 3)
      FactoryGirl.create(:api, :name => "API B", :sort_order => 1)
      FactoryGirl.create(:api, :name => "API C", :sort_order => 2)
      FactoryGirl.create(:api, :name => "API testing-filter", :sort_order => 4)
    end

    it "shows the drag handle when the reorder button is clicked and hides when the done button is clicked" do
      visit "/admin/#/apis"

      all("tbody td.reorder-handle").length.should eql(0)
      click_button "Reorder"
      sleep 2
      all("tbody td.reorder-handle").length.should eql(4)
      click_button "Done"
      sleep 2
      all("tbody td.reorder-handle").length.should eql(0)
    end

    it "removes filters when in reorder mode" do
      visit "/admin/#/apis"

      all("tbody tr").length.should eql(4)
      find(".dataTables_filter input").set("testing-fi")
      wait_for_datatables_filter
      all("tbody tr").length.should eql(1)
      click_button "Reorder"
      wait_for_datatables_filter
      all("tbody tr").length.should eql(4)
    end

    it "forces sorting by matching order when in reorder mode" do
      visit "/admin/#/apis"
      names = all("tbody td:first-child").map { |cell| cell.text }
      names.should eql(["API A", "API B", "API C", "API testing-filter"])
      click_button "Reorder"
      sleep 3
      names = all("tbody td:first-child").map { |cell| cell.text }
      names.should eql(["API B", "API C", "API A", "API testing-filter"])
    end

    it "exits reorder mode when a filter is applied after entering reorder mode" do
      visit "/admin/#/apis"
      click_button "Reorder"
      sleep 2
      all("tbody td.reorder-handle").length.should eql(4)
      find(".dataTables_filter input").set("testing-fi")
      wait_for_datatables_filter
      sleep 2
      all("tbody td.reorder-handle").length.should eql(0)
    end

    it "exits reorder mode when an order is applied after entering reorder mode" do
      visit "/admin/#/apis"
      click_button "Reorder"
      sleep 2
      all("tbody td.reorder-handle").length.should eql(4)
      find("thead tr:first-child").click
      sleep 2
      all("tbody td.reorder-handle").length.should eql(0)
    end

    it "performs reordering on drag" do
      visit "/admin/#/apis"

      names = Api.sorted.all.map { |api| api.name }
      names.should eql(["API B", "API C", "API A", "API testing-filter"])

      click_button "Reorder"

      # Simulate the drag and drop using jquery-simulate-ext (capybara supports
      # dropping, but not the dragging behavior jquery-ui needs).
      page.execute_script %{
        $('tbody td:contains("API A")')
          .siblings('td.reorder-handle')
          .simulate('drag-n-drop', { dy: -70 });
      }
      wait_for_ajax

      names = Api.sorted.all.map { |api| api.name }
      names.should eql(["API A", "API B", "API C", "API testing-filter"])
    end
  end

  describe "saving" do
    before(:each) do
      @api = FactoryGirl.create(:api_with_settings, :name => "Save Test API")
    end

    it "saves the record when only the nested object attributes contain changes" do
      @api.settings.error_data.should eql(nil)

      visit "/admin/#/apis"
      click_link "Save Test API"

      find_field("Name").value.should eql("Save Test API")
      page.save_screenshot('screenshot1.png')

      find("a", :text => /Advanced Settings/).click
      page.execute_script %{
        ace.edit($('[data-form-property=api_key_missing]')[0]).setValue('hello1: foo\\nhello2: bar');
      }

      page.save_screenshot('screenshot2.png')
      click_button("Save")
      page.save_screenshot('screenshot3.png')
      page.should have_content("Successfully saved")

      @api = Api.find(@api.id)
      @api.settings.error_data.should eql({
        "api_key_missing" => {
          "hello1" => "foo",
          "hello2" => "bar",
        }
      })
    end
  end

  describe "loading" do
    before(:each) do
      @api = FactoryGirl.create(:api_with_settings, :name => "Test Load API", :frontend_host => "example1.com")
    end

    it "loads the record from the server each time the form opens, even if the data is pre-cached" do
      visit "/admin/#/apis"
      page.should have_content("Add API Backend")

      click_link "Test Load API"
      find_field("Frontend Host").value.should eql("example1.com")

      find("nav a", :text => /Configuration/).click
      find("nav a", :text => /API Backends/).click
      page.should have_content("Add API Backend")

      @api.frontend_host = "example2.com"
      @api.save!

      click_link "Test Load API"
      find_field("Frontend Host").value.should eql("example2.com")
    end
  end
end
