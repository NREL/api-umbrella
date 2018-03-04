require_relative "../test_helper"

class Test::AdminUi::TestDatatables < Minitest::Capybara::Test
  include Capybara::Screenshot::MiniTestPlugin
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
  end

  def test_uses_placeholder_not_label_for_search_field
    admin_login
    visit "/admin/#/api_users"
    assert_equal("", find(".dataTables_filter").text)
    assert_equal("Search...", find(".dataTables_filter input")[:placeholder])
  end

  def test_spinner_on_server_side_loads
    admin_login
    visit "/admin/"
    delay_all_ajax_calls

    find("nav a", :text => /Users/).click
    find("nav a", :text => /API Users/).click

    assert_selector(".busy-blocker")
    refute_selector(".busy-blocker")

    find("thead tr:first-child").click
    assert_selector(".busy-blocker")
    refute_selector(".busy-blocker")
  end

  private

  def delay_all_ajax_calls(delay = 1000)
    page.execute_script <<-EOS
      $.ajaxOrig = $.ajax;
      $.ajax = function() {
        var args = arguments;
        var self = this;
        setTimeout(function() {
          $.ajaxOrig.apply(self, args);
        }, #{delay});
      };
    EOS
  end
end
