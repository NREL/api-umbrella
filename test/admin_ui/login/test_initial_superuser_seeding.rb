require_relative "../../test_helper"

class Test::AdminUi::Login::TestInitialSuperuserSeeding < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include Minitest::Hooks

  def setup
    super
    setup_server
    once_per_class_setup do
      assert_equal(0, Admin.count)

      override_config_set({
        "web" => {
          "admin" => {
            "initial_superusers" => [
              "initial.admin@example.com",
            ],
          },
        },
      })
    end
  end

  def after_all
    super
    override_config_reset
  end

  def test_initial_superusers
    admins = Admin.where(:username => "initial.admin@example.com").all
    assert_equal(1, admins.length)

    admin = admins.first
    assert(admin.superuser)
    assert_match(/\A[0-9a-f-]{36}\z/, admin.id)
    assert_match(/\A[a-zA-Z0-9]{40}\z/, admin.authentication_token)
    assert_nil(admin.password_hash)
  end
end
