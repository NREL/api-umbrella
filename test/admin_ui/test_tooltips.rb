require_relative "../test_helper"

class Test::AdminUi::TestTooltips < Minitest::Capybara::Test
  include Capybara::Screenshot::MiniTestPlugin
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
  end

  def test_tooltips_markdown
    admin_login
    visit "/admin/#/apis/new"

    # Find the tooltip
    find("legend a", :text => /Global Request Settings/).click
    label = find("label", :text => "HTTPS Requirements")
    tooltip = label.first(:xpath, "..").first("a[rel=tooltip]")

    # Check for the screen reader value inside the tooltip.
    assert_equal("Help", tooltip.text)

    # Check that the tooltip pops up when clicked.
    refute_text("Choose whether HTTPS is required")
    tooltip.click
    assert_text("Choose whether HTTPS is required")

    # Check that the tooltip content gets translated from markdown into HTML
    # (this "Required:" label should be bold and inside a list).
    assert_selector(".qtip-content ul li strong", :text => "Required:")
  end
end
