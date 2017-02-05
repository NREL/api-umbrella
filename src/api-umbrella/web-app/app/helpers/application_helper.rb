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
    user = ApiUser.where(:email => "web.admin.ajax@internal.apiumbrella").order_by(:created_at.asc).first
    unless(user)
      user = ApiUser.create!({
        :email => "web.admin.ajax@internal.apiumbrella",
        :first_name => "API Umbrella Admin",
        :last_name => "Key",
        :use_description => "An API key for the API Umbrella admin to use for internal ajax requests.",
        :terms_and_conditions => "1",
        :registration_source => "seed",
        :settings_attributes => { :rate_limit_mode => "unlimited" },
      }, :without_protection => true)
    end

    user
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
    ApiUmbrellaConfig[:web][:admin][:auth_strategies][:_local_enabled?] || ApiUmbrellaConfig[:web][:admin][:auth_strategies][:_only_ldap_enabled?]
  end

  def ldap_title
    strategy = Devise.omniauth_configs[:ldap].strategy
    strategy[:title].presence || t(:ldap, :scope => [:omniauth_providers])
  end
end
