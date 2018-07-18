require_relative "../test_helper"

class Test::AdminUi::TestApisReordering < Minitest::Capybara::Test
  include Capybara::Screenshot::MiniTestPlugin
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server

    Api.delete_all
    FactoryBot.create(:api, :name => "API A", :sort_order => 3)
    FactoryBot.create(:api, :name => "API B", :sort_order => 1)
    FactoryBot.create(:api, :name => "API C", :sort_order => 2)
    FactoryBot.create(:api, :name => "API testing-filter", :sort_order => 4)
  end

  def test_toggle_drag_handles
    admin_login
    visit "/admin/#/apis"
    refute_selector(".busy-blocker")
    assert_text("API A")

    refute_selector("tbody td.reorder-handle")
    click_button "Reorder"
    assert_selector("tbody td.reorder-handle", :count => 4)
    click_button "Done"
    refute_selector("tbody td.reorder-handle")
  end

  def test_remove_filters_while_reordering
    admin_login
    visit "/admin/#/apis"
    refute_selector(".busy-blocker")
    assert_text("API A")

    assert_selector("tbody tr", :count => 4)
    find(".dataTables_filter input").set("testing-fi")
    assert_selector("tbody tr", :count => 1)
    click_button "Reorder"
    assert_selector("tbody tr", :count => 4)
  end

  def test_forces_sorting_while_reordering
    admin_login
    visit "/admin/#/apis"
    refute_selector(".busy-blocker")
    assert_text("API A")

    assert_selector("tbody tr:first-child td:first-child", :text => "API A")
    click_button "Reorder"
    assert_selector("tbody tr:first-child td:first-child", :text => "API B")
  end

  def test_exits_reorder_mode_on_filter
    admin_login
    visit "/admin/#/apis"
    refute_selector(".busy-blocker")
    assert_text("API A")

    click_button "Reorder"
    assert_selector("tbody td.reorder-handle", :count => 4)
    find(".dataTables_filter input").set("testing-fi")
    refute_selector("tbody td.reorder-handle")
  end

  def test_exit_reorder_mode_on_sort
    admin_login
    visit "/admin/#/apis"
    refute_selector(".busy-blocker")
    assert_text("API A")

    click_button "Reorder"
    assert_selector("tbody td.reorder-handle", :count => 4)
    find("thead tr:first-child").click
    refute_selector("tbody td.reorder-handle")
  end

  def test_reordering_on_drag
    admin_login
    visit "/admin/#/apis"
    refute_selector(".busy-blocker")
    assert_text("API A")

    names = Api.order_by(:sort_order.asc).all.map { |api| api.name }
    assert_equal(["API B", "API C", "API A", "API testing-filter"], names)

    click_button "Reorder"

    refute_selector(".busy-blocker")
    assert_selector("tbody tr:first-child td:first-child", :text => "API B")
    handle = find("tbody td:first-child", :text => "API A").find(:xpath, "..").find("td.reorder-handle")
    handle.native.drag_by(0, -70)
    assert_selector("tbody tr:first-child td:first-child", :text => "API A")
    refute_selector(".busy-blocker")

    names = Api.order_by(:sort_order.asc).all.map { |api| api.name }
    assert_equal(["API A", "API B", "API C", "API testing-filter"], names)
  end
end
