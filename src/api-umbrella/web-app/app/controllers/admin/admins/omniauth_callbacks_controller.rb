class Admin::Admins::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  skip_after_action :verify_authorized

  # For the developer strategy, simply find or create a new admin account with
  # whatever login details they give. This is not for use on production.
  def developer
    unless(Rails.env.development?)
      raise "The developer OmniAuth strategy should not be used outside of development or test."
    end

    @username = request.env["omniauth.auth"]["uid"]
    @admin = Admin.find_for_database_authentication(:username => @username)
    unless(@admin)
      @admin = Admin.new(:username => @username, :superuser => true)
      @admin.save!
    end

    login
  rescue Mongoid::Errors::Validations
    flash[:error] = @admin.errors.full_messages.join(", ")
    redirect_to admin_developer_omniauth_authorize_path
  end

  def cas
    if(ApiUmbrellaConfig[:web][:admin][:auth_strategies][:"max.gov"][:require_mfa])
      if(!request.env["omniauth.auth"]["extra"] || !request.env["omniauth.auth"]["extra"]["MaxSecurityLevel"] || !request.env["omniauth.auth"]["extra"]["MaxSecurityLevel"].include?("securePlus2"))
        return mfa_required_error
      end
    end

    @username = request.env["omniauth.auth"]["uid"]
    login
  end

  def facebook
    @username = request.env["omniauth.auth"]["info"]["email"]
    if(!request.env["omniauth.auth"]["info"]["verified"])
      return email_unverified_error
    end

    login
  end

  def github
    # omniauth-github only returns verified emails by default (so no explicit
    # verification check is needed):
    # https://github.com/intridea/omniauth-github/pull/48
    @username = request.env["omniauth.auth"]["info"]["email"]

    login
  end

  def gitlab
    # GitLab only appears to return verified email addresses (so there's not an
    # explicit email verification attribute or check needed).
    @username = request.env["omniauth.auth"]["info"]["email"]

    login
  end

  def google_oauth2
    @username = request.env["omniauth.auth"]["info"]["email"]
    if(!request.env["omniauth.auth"]["extra"]["raw_info"]["email_verified"])
      return email_unverified_error
    end

    login
  end

  def ldap
    uid_field = request.env["omniauth.strategy"].options[:uid]
    uid = [request.env["omniauth.auth"]["extra"]["raw_info"][uid_field]].flatten.compact.first
    @username = uid
    login
  end

  private

  def login
    if(!@admin && @username.present?)
      @admin = Admin.find_for_database_authentication(:username => @username)
    end

    if @admin
      if request.env["omniauth.auth"]["info"].present?
        if request.env["omniauth.auth"]["info"]["name"].present?
          @admin.name = request.env["omniauth.auth"]["info"]["name"]
          @admin.save!
        end
      end

      sign_in_and_redirect(:admin, @admin)
    else
      flash[:error] = ActionController::Base.helpers.safe_join([
        "The account for '",
        @username,
        "' is not authorized to access the admin. Please ",
        ActionController::Base.helpers.content_tag(:a, "contact us", :href => ApiUmbrellaConfig[:contact_url]),
        " for further assistance.",
      ])
      flash[:html_safe] = true

      redirect_to new_admin_session_path
    end
  end

  def email_unverified_error
    flash[:error] = ActionController::Base.helpers.safe_join([
      "The email address '",
      @username,
      "' is not verified. Please ",
      ActionController::Base.helpers.content_tag(:a, "contact us", :href => ApiUmbrellaConfig[:contact_url]),
      " for further assistance.",
    ])
    flash[:html_safe] = true

    redirect_to new_admin_session_path
  end

  def mfa_required_error
    flash[:error] = ActionController::Base.helpers.safe_join([
      "You must use multi-factor authentication to sign in. Please try again, or ",
      ActionController::Base.helpers.content_tag(:a, "contact us", :href => ApiUmbrellaConfig[:contact_url]),
      " for further assistance.",
    ])
    flash[:html_safe] = true

    redirect_to new_admin_session_path
  end

  def after_omniauth_failure_path_for(scope)
    new_admin_session_path
  end
end
