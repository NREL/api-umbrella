require_relative "../test_helper"

class Test::AdminUi::TestLocales < Minitest::Capybara::Test
  include Capybara::Screenshot::MiniTestPlugin
  include ApiUmbrellaTestHelpers::AdminAuth
  include ApiUmbrellaTestHelpers::Setup

  LOCALES_ROOT_DIR = File.join(API_UMBRELLA_SRC_ROOT, "locale")
  EXPECTED_I18N = {
    :de => {
      :allowed_ips => "IP-Adresse Beschränkungen",
      :analytics => "Analytics",
      :forgot_password => "Passwort vergessen?",
      :password => "Passwort",
    },
    :en => {
      :allowed_ips => "Restrict Access to IPs",
      :analytics => "Analytics",
      :forgot_password => "Forgot your password?",
      :password => "Password",
    },
    :"es-419" => {
      :allowed_ips => "Restringir acceso a IPs",
      :analytics => "Analítica",
      :forgot_password => "¿Ha olvidado su contraseña?",
      :password => "Contraseña",
    },
    :fi => {
      :allowed_ips => "Rajoita pääsyä IP:siin",
      :analytics => "Analytiikka",
      :forgot_password => "Unohditko salasanasi?",
      :password => "Salasana",
    },
    :fr => {
      :allowed_ips => "Liste noire IP",
      :analytics => "Statistiques",
      :forgot_password => "Mot de passe oublié ?",
      :password => "Mot de passe",
    },
    :it => {
      :allowed_ips => "Limita Accesso ad IP",
      :analytics => "Analitiche",
      :forgot_password => "Password dimenticata?",
      :password => "Password",
    },
    :ru => {
      :allowed_ips => "Ограничить доступ к IP",
      :analytics => "Аналитика",
      :forgot_password => "Забыли пароль?",
      :password => "Пароль",
    },
  }.freeze

  def setup
    super
    setup_server

    # Ensure at least one admin exists so the login page can be hit directly
    # without redirecting to the first-time admin create page.
    FactoryBot.create(:admin)
  end

  # Test all the available locales except the special test "zy" (which we use
  # to test for incomplete data).
  valid_locales = EXPECTED_I18N.keys
  valid_locales.each do |locale|
    locale_method_name = locale.to_s.downcase.gsub(/[^\w]/, "_")

    define_method("test_server_side_translations_in_#{locale_method_name}_locale") do
      selenium_use_language_driver(locale.to_s)
      visit "/admin/login"

      # From devise-i18n based on attribute names
      assert_i18n_text(locale, :password, find("label[for=admin_password]"))

      # From devise-i18n manually assigned in view
      assert_i18n_text(locale, :forgot_password, find("a[href='/admins/password/new']"))
    end

    define_method("test_client_side_translations_in_#{locale_method_name}_locale") do
      selenium_use_language_driver(locale.to_s)
      admin_login
      visit "/admin/#/api_users/new"

      # Form
      assert_i18n_text(locale, :allowed_ips, find("label[for$='allowedIpsString']"))

      # Navigation
      assert_i18n_text(locale, :analytics, find("li.nav-analytics > a"))
    end
  end

  def test_server_side_fall_back_to_english_for_unknown_locale
    locale = "zz"
    selenium_use_language_driver(locale)
    visit "/admin/login"

    refute_path_exists(File.join(LOCALES_ROOT_DIR, "#{locale}.po"))
    assert_i18n_text(:en, :password, find("label[for=admin_password]"))
  end

  def test_client_side_fall_back_to_english_for_unknown_locale
    locale = "zz"
    selenium_use_language_driver(locale)
    admin_login
    visit "/admin/#/api_users/new"

    refute_path_exists(File.join(LOCALES_ROOT_DIR, "#{locale}.po"))
    assert_i18n_text(:en, :allowed_ips, find("label[for$='allowedIpsString']"))
  end

  def test_server_side_fall_back_to_english_for_missing_data_in_known_locale
    locale = "zy"
    selenium_use_language_driver(locale)
    visit "/admin/login"

    assert_path_exists(File.join(LOCALES_ROOT_DIR, "#{locale}.po"))
    assert_i18n_text(:en, :password, find("label[for=admin_password]"))
  end

  def test_client_side_fall_back_to_english_for_missing_data_in_known_locale
    locale = "zy"
    selenium_use_language_driver(locale)
    admin_login
    visit "/admin/#/api_users/new"

    assert_path_exists(File.join(LOCALES_ROOT_DIR, "#{locale}.po"))
    assert_i18n_text(:en, :allowed_ips, find("label[for$='allowedIpsString']"))
  end

  private

  def assert_i18n_text(expected_locale, expected_key, element)
    assert(element)

    expected_text = EXPECTED_I18N.fetch(expected_locale).fetch(expected_key)
    refute_empty(expected_text)
    assert_equal(expected_text, element.text)
  end
end
