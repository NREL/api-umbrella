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
      all("tbody td.reorder-handle").length.should eql(4)
      click_button "Done"
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
      sleep 1
      names = all("tbody td:first-child").map { |cell| cell.text }
      names.should eql(["API B", "API C", "API A", "API testing-filter"])
    end

    it "exits reorder mode when a filter is applied after entering reorder mode" do
      visit "/admin/#/apis"
      click_button "Reorder"
      all("tbody td.reorder-handle").length.should eql(4)
      find(".dataTables_filter input").set("testing-fi")
      wait_for_datatables_filter
      sleep 1
      all("tbody td.reorder-handle").length.should eql(0)
    end

    it "exits reorder mode when an order is applied after entering reorder mode" do
      visit "/admin/#/apis"
      click_button "Reorder"
      all("tbody td.reorder-handle").length.should eql(4)
      find("thead tr:first-child").click
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
end
