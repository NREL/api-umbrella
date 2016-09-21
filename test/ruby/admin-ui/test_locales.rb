require "test_helper"

locales_root_dir = File.expand_path("../../../../src/api-umbrella/web-app/config/locales", __FILE__)
I18n.load_path = Dir[File.join(locales_root_dir, "*.yml")]
I18n.backend.load_translations

class TestAdminUiLocales < Minitest::Capybara::Test
  include Capybara::Screenshot::MiniTestPlugin
  include ApiUmbrellaTests::AdminAuth
  include ApiUmbrellaTests::Setup

  def setup
    setup_server
  end

  I18n.available_locales.each do |locale|
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
      refute_empty(I18n.t("mongoid.attributes.api/settings.allowed_ips", :locale => locale))
      assert_text(I18n.t("mongoid.attributes.api/settings.allowed_ips", :locale => locale))
      if(locale != :en)
        refute_empty(I18n.t("mongoid.attributes.api/settings.allowed_ips", :locale => :en))
        refute_text(I18n.t("mongoid.attributes.api/settings.allowed_ips", :locale => :en))
      end
    end
  end

  def test_server_side_fall_back_to_english_for_unknown_locale
    page.driver.add_headers("Accept-Language" => "zz")
    visit "/admin/login"
    refute_empty(I18n.t("omniauth_providers.developer", :locale => :en))
    assert_text(I18n.t("omniauth_providers.developer", :locale => :en))
  end

  def test_client_side_fall_back_to_english_for_unknown_locale
    page.driver.add_headers("Accept-Language" => "zz")
    admin_login
    visit "/admin/#/api_users/new"
    refute_empty(I18n.t("mongoid.attributes.api/settings.allowed_ips", :locale => :en))
    assert_text(I18n.t("mongoid.attributes.api/settings.allowed_ips", :locale => :en))
  end
end
