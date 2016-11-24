require_relative "../test_helper"

locales_root_dir = File.join(API_UMBRELLA_SRC_ROOT, "src/api-umbrella/web-app/config/locales")
I18n.load_path = Dir[File.join(locales_root_dir, "*.yml")]
I18n.backend.load_translations

class Test::AdminUi::TestLocales < Minitest::Capybara::Test
  include Capybara::Screenshot::MiniTestPlugin
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  def setup
    setup_server
  end

  # Test all the available locales except the special test "zy" (which we use
  # to test for incomplete data).
  valid_locales = I18n.available_locales - [:zy]
  valid_locales.each do |locale|
    locale_method_name = locale.to_s.downcase.gsub(/[^\w]/, "_")

    define_method("test_server_side_translations_in_#{locale_method_name}_locale") do
      page.driver.add_headers("Accept-Language" => locale.to_s)
      visit "/admin/login"
      refute_empty(I18n.t("omniauth_providers.developer", :locale => locale))
      assert_text(I18n.t("omniauth_providers.developer", :locale => locale))
      if(locale != :en)
        refute_empty(I18n.t("omniauth_providers.developer", :locale => :en))
        refute_text(I18n.t("omniauth_providers.developer", :locale => :en))
      end
    end

    define_method("test_client_side_translations_in_#{locale_method_name}_locale") do
      page.driver.add_headers("Accept-Language" => locale.to_s)
      admin_login
      visit "/admin/#/api_users/new"

      # Form
      refute_empty(I18n.t("mongoid.attributes.api/settings.allowed_ips", :locale => locale))
      assert_text(I18n.t("mongoid.attributes.api/settings.allowed_ips", :locale => locale))
      if(locale != :en)
        refute_empty(I18n.t("mongoid.attributes.api/settings.allowed_ips", :locale => :en))
        refute_text(I18n.t("mongoid.attributes.api/settings.allowed_ips", :locale => :en))
      end

      # Navigation
      refute_empty(I18n.t("admin.nav.analytics", :locale => locale))
      assert_text(I18n.t("admin.nav.analytics", :locale => locale))
    end
  end

  def test_server_side_fall_back_to_english_for_unknown_locale
    page.driver.add_headers("Accept-Language" => "zz")
    visit "/admin/login"
    assert_raises I18n::InvalidLocale do
      I18n.t("omniauth_providers.developer", :locale => :zz)
    end
    refute_empty(I18n.t("omniauth_providers.developer", :locale => :en))
    assert_text(I18n.t("omniauth_providers.developer", :locale => :en))
  end

  def test_client_side_fall_back_to_english_for_unknown_locale
    page.driver.add_headers("Accept-Language" => "zz")
    admin_login
    visit "/admin/#/api_users/new"
    assert_raises I18n::InvalidLocale do
      I18n.t("mongoid.attributes.api/settings.allowed_ips", :locale => :zz)
    end
    refute_empty(I18n.t("mongoid.attributes.api/settings.allowed_ips", :locale => :en))
    assert_text(I18n.t("mongoid.attributes.api/settings.allowed_ips", :locale => :en))
  end

  def test_server_side_fall_back_to_english_for_missing_data_in_known_locale
    page.driver.add_headers("Accept-Language" => "zy")
    visit "/admin/login"
    assert_equal("translation missing: zy.omniauth_providers.developer", I18n.t("omniauth_providers.developer", :locale => :zy))
    assert_text(I18n.t("omniauth_providers.developer", :locale => :en))
  end

  def test_client_side_fall_back_to_english_for_missing_data_in_known_locale
    page.driver.add_headers("Accept-Language" => "zy")
    admin_login
    visit "/admin/#/api_users/new"
    assert_equal("translation missing: zy.mongoid.attributes.api/settings.allowed_ips", I18n.t("mongoid.attributes.api/settings.allowed_ips", :locale => :zy))
    assert_text(I18n.t("mongoid.attributes.api/settings.allowed_ips", :locale => :en))
  end
end
