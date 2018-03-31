require_relative "../test_helper"

class Test::AdminUi::TestApiScopes < Minitest::Capybara::Test
  include Capybara::Screenshot::MiniTestPlugin
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    super
    setup_server
  end

  def test_create
    admin_login
    visit("/admin/#/api_scopes/new")

    fill_in("Name", :with => "Example")
    fill_in("Host", :with => "example.com")
    fill_in("Path Prefix", :with => "/foo/")

    click_button("Save")
    assert_text("Successfully saved")

    api_scope = ApiScope.order(:created_at => :desc).first
    assert_equal("Example", api_scope.name)
    assert_equal("example.com", api_scope.host)
    assert_equal("/foo/", api_scope.path_prefix)
  end

  def test_update
    api_scope = FactoryBot.create(:api_scope, :name => "Example", :path_prefix => "/example")

    admin_login
    visit("/admin/#/api_scopes/#{api_scope.id}/edit")

    assert_field("Name", :with => "Example")
    assert_field("Host", :with => "localhost")
    assert_field("Path Prefix", :with => "/example")

    fill_in("Name", :with => "Example2")
    fill_in("Host", :with => "2.example.com")
    fill_in("Path Prefix", :with => "/2/")

    click_button("Save")
    assert_text("Successfully saved")

    api_scope.reload
    assert_equal("Example2", api_scope.name)
    assert_equal("2.example.com", api_scope.host)
    assert_equal("/2/", api_scope.path_prefix)
  end
end
