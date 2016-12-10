class Admin::SessionsController < Devise::SessionsController
  skip_after_action :verify_authorized

  def new
  end

  def after_sign_out_path_for(resource_or_scope)
    admin_path
  end

  def auth
    response = {
      "authenticated" => !current_admin.nil?,
      "enable_beta_analytics" => (ApiUmbrellaConfig[:analytics][:adapter] == "kylin" || (ApiUmbrellaConfig[:analytics][:outputs] && ApiUmbrellaConfig[:analytics][:outputs].include?("kylin"))),
    }

    if current_admin
      response["api_umbrella_version"] = API_UMBRELLA_VERSION
      response["admin"] = current_admin.as_json
      response["api_key"] = ApiUser.where(:email => "web.admin.ajax@internal.apiumbrella").order_by(:created_at.asc).first.api_key
      response["csrf_token"] = form_authenticity_token if(protect_against_forgery?)
    end

    respond_to do|format|
      format.json { render(:json => response) }
    end
  end
end
