module ApplicationHelper
  def bootstrap_class_for(flash_type)
    case flash_type.to_s
    when "success"
      "alert-success"
    when "error"
      "alert-danger"
    when "alert"
      "alert-warning"
    when "notice"
      "alert-info"
    else
      "alert-#{flash_type}"
    end
  end

  def web_admin_ajax_api_user
    ApiUser.where(:email => "web.admin.ajax@internal.apiumbrella").order_by(:created_at.asc).first
  end

  def omniauth_external_providers
    unless @omniauth_external_providers
      @omniauth_external_providers = Admin.omniauth_providers
      if(ApiUmbrellaConfig[:web][:admin][:auth_strategies][:_only_ldap_enabled?])
        @omniauth_external_providers.delete(:ldap)
      end
    end

    @omniauth_external_providers
  end

  def display_login_form?
    ApiUmbrellaConfig[:web][:admin][:auth_strategies][:_enabled][:local] || ApiUmbrellaConfig[:web][:admin][:auth_strategies][:_only_ldap_enabled?]
  end

  def ldap_title
    strategy = Devise.omniauth_configs[:ldap].strategy
    strategy[:title].presence || t(:ldap, :scope => [:omniauth_providers])
  end
end
