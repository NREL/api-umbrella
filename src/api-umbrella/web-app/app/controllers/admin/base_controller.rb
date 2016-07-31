class Admin::BaseController < ApplicationController
  before_filter :authenticate_admin!
  after_filter :verify_authorized
  skip_after_filter :verify_authorized, :only => [:empty]
  before_filter :set_locale

  layout "admin"

  def empty
    render(:text => "", :layout => true)
  end

  private

  def set_locale
    I18n.locale = http_accept_language.compatible_language_from(I18n.available_locales)
  end
end
