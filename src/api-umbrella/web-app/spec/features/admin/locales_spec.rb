require "rails_helper"

RSpec.describe "locales", :js => true do
  describe "login page" do
    I18n.available_locales.each do |locale|
      it "translates in #{locale}" do
        page.driver.add_headers("Accept-Language" => locale.to_s)
        visit "/admin/login"
        page.should have_content(I18n.t("omniauth_providers.developer", :locale => locale))
      end

      it "falls back to english for unknown languages" do
        page.driver.add_headers("Accept-Language" => "zz")
        visit "/admin/login"
        page.should have_content(I18n.t("omniauth_providers.developer", :locale => "en"))
      end
    end
  end

  describe "admin" do
    login_admin

    describe "server-side and client-side js translations" do
      I18n.available_locales.each do |locale|
        it "translates in #{locale}" do
          page.driver.add_headers("Accept-Language" => locale.to_s)
          visit "/admin/#/apis/new"

          # Server-side rendered i18n
          page.should have_content(I18n.t("admin.nav.analytics", :locale => locale))

          # Client-side rendered i18n
          page.should have_content(I18n.t("admin.api.servers.add", :locale => locale))
        end

        it "falls back to english for unknown languages" do
          page.driver.add_headers("Accept-Language" => "zz")
          visit "/admin/#/apis/new"

          # Server-side rendered i18n
          page.should have_content(I18n.t("admin.nav.analytics", :locale => "en"))

          # Client-side rendered i18n
          page.should have_content(I18n.t("admin.api.servers.add", :locale => "en"))
        end
      end
    end
  end
end
