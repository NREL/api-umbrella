require_relative "../../test_helper"

class Test::AdminUi::Login::TestInitialSuperuserSeeding < Minitest::Test
  include ApiUmbrellaTestHelpers::Setup
  include Minitest::Hooks

  def setup
    super
    setup_server
    once_per_class_setup do
      Admin.delete_all
      assert_equal(0, Admin.count)

      override_config_set({
        "web" => {
          "admin" => {
            "initial_superusers" => [
              "initial.admin@example.com",
            ],
          },
        },
      }, ["--router"])
    end
  end

  def after_all
    super
    override_config_reset(["--router"])
  end

  def test_initial_superusers
    admins = Admin.where(:username => "initial.admin@example.com").all
    assert_equal(1, admins.length)

    admin = admins.first.attributes
    assert(admin["superuser"])
    assert_match(/\A[0-9a-f\-]{36}\z/, admin["_id"])
    assert_match(/\A[a-zA-Z0-9]{40}\z/, admin["authentication_token"])
    assert_nil(admin["encrypted_password"])
  end
end
