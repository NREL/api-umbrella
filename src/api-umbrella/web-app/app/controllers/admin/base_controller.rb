class Admin::BaseController < ApplicationController
  before_action :authenticate_admin!
  after_action :verify_authorized
  skip_after_action :verify_authorized, :only => [:empty]
  before_action :set_locale

  private

  def set_locale
    I18n.locale = http_accept_language.compatible_language_from(I18n.available_locales)
  end
end
