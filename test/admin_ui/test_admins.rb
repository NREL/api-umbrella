require_relative "../test_helper"

class Test::AdminUi::TestAdmins < Minitest::Capybara::Test
  include Capybara::Screenshot::MiniTestPlugin
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    setup_server
  end

  def test_superuser_checkbox_as_superuser_admin
    admin_login
    visit "/admin/#/admins/new"

    assert_content("Email")
    assert_content("Superuser")
  end

  def test_superuser_checkbox_as_limited_admin
    admin_login(FactoryGirl.create(:limited_admin))
    visit "/admin/#/admins/new"

    assert_content("Email")
    refute_content("Superuser")
  end

  def test_adds_groups_when_checked
    admin_login

    @group1 = FactoryGirl.create(:admin_group)
    @group2 = FactoryGirl.create(:admin_group)
    @group3 = FactoryGirl.create(:admin_group)

    admin = FactoryGirl.create(:admin)
    assert_equal([], admin.group_ids)

    visit "/admin/#/admins/#{admin.id}/edit"

    check @group1.name
    check @group3.name

    click_button("Save")

    assert_content("Successfully saved the admin")

    admin = Admin.find(admin.id)
    assert_equal([@group1.id, @group3.id].sort, admin.group_ids.sort)
  end

  def test_removes_groups_when_checked
    admin_login

    @group1 = FactoryGirl.create(:admin_group)
    @group2 = FactoryGirl.create(:admin_group)
    @group3 = FactoryGirl.create(:admin_group)

    admin = FactoryGirl.create(:admin, :groups => [@group1, @group2])
    assert_equal([@group1.id, @group2.id].sort, admin.group_ids.sort)

    visit "/admin/#/admins/#{admin.id}/edit"

    uncheck @group1.name
    uncheck @group2.name
    check @group3.name

    click_button("Save")

    assert_content("Successfully saved the admin")

    admin = Admin.find(admin.id)
    assert_equal([@group3.id].sort, admin.group_ids.sort)
  end
end
