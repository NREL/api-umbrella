class Admin::SessionsController < Devise::SessionsController
  before_filter :set_locale

  def new
  end

  def after_sign_out_path_for(resource_or_scope)
    admin_path
  end

  def auth
    response = {
      "authenticated" => !!current_admin,
    }

    if current_admin
      response["admin"] = current_admin.as_json
      response["api_key"] = ApiUser.where(:email => "web.admin.ajax@internal.apiumbrella").order_by(:created_at.asc).first.api_key
      response["csrf_token"] = form_authenticity_token if(protect_against_forgery?)
    end

    respond_to do|format|
      format.json { render(:json => response) }
    end
  end

  private

  def set_locale
    I18n.locale = http_accept_language.compatible_language_from(I18n.available_locales)
  end
end
