class Admin::Admins::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  skip_after_action :verify_authorized

  # The developer strategy doesn't include the CSRF token in the form:
  # https://github.com/omniauth/omniauth/pull/674
  skip_before_action :verify_authenticity_token, :only => :developer

  # For the developer strategy, simply find or create a new admin account with
  # whatever login details they give. This is not for use on production.
  def developer
    unless(%w(development test).include?(Rails.env))
      raise "The developer OmniAuth strategy should not be used outside of development or test."
    end

    @email = request.env["omniauth.auth"]["uid"]
    @admin = Admin.where(:username => @email).first
    @admin ||= Admin.create!(:username => @email, :superuser => true)

    login
  end

  def cas
    @email = request.env["omniauth.auth"]["uid"]
    login
  end

  def facebook
    if(request.env["omniauth.auth"]["info"]["verified"])
      @email = request.env["omniauth.auth"]["info"]["email"]
    end

    login
  end

  def github
    if(request.env["omniauth.auth"]["info"]["email_verified"])
      @email = request.env["omniauth.auth"]["info"]["email"]
    end

    login
  end

  def google_oauth2
    if(request.env["omniauth.auth"]["extra"]["raw_info"]["email_verified"])
      @email = request.env["omniauth.auth"]["info"]["email"]
    end

    login
  end

  def ldap
    uid_field = request.env["omniauth.strategy"].options[:uid]
    uid = [request.env["omniauth.auth"]["extra"]["raw_info"][uid_field]].flatten.compact.first
    @email = uid
    login
  end

  private

  def login
    if(!@admin && @email.present?)
      @admin = Admin.where(:username => @email.downcase).first
    end

    if @admin
      @admin.last_sign_in_provider = request.env["omniauth.auth"]["provider"]
      if request.env["omniauth.auth"]["info"].present?
        if request.env["omniauth.auth"]["info"]["email"].present?
          @admin.email = request.env["omniauth.auth"]["info"]["email"]
        end

        if request.env["omniauth.auth"]["info"]["name"].present?
          @admin.name = request.env["omniauth.auth"]["info"]["name"]
        end
      end

      @admin.save!

      sign_in_and_redirect(:admin, @admin)
    else
      flash[:error] = ActionController::Base.helpers.safe_join([
        "The account for '",
        @email,
        "' is not authorized to access the admin. Please ",
        ActionController::Base.helpers.content_tag(:a, "contact us", :href => ApiUmbrellaConfig[:contact_url]),
        " for further assistance.",
      ])

      redirect_to new_admin_session_path
    end
  end

  def signed_in_root_path(resource_or_scope)
    admin_path
  end

  def after_omniauth_failure_path_for(scope)
    new_admin_session_path
  end
end
