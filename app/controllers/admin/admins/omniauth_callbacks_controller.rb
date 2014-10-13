class Admin::Admins::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  # For the developer strategy, simply find or create a new admin account with
  # whatever login details they give. This is not for use on production.
  def developer
    unless(%w(development test).include?(Rails.env))
      raise "The developer OmniAuth strategy should not be used outside of development or test."
    end

    omniauth = env["omniauth.auth"]
    @admin = Admin.where(:username => omniauth["uid"]).first
    @admin ||= Admin.new({ :username => omniauth["uid"], :superuser => true }, :without_protection => true)
    @admin.apply_omniauth(omniauth)
    @admin.save!
    sign_in(:admin, @admin)
    redirect_to admin_path
  end

  def cas
    @email = env["omniauth.auth"]["uid"]
    login
  end

  def facebook
    if(env["omniauth.auth"]["info"]["verified"])
      @email = env["omniauth.auth"]["info"]["email"]
    end

    login
  end

  def github
    emails = env["omniauth.auth"]["extra"]["raw_info"]["emails"]
    primary = emails.select { |email| email["primary"] && email["email"] == env["omniauth.auth"]["info"]["email"] }
    if(primary && primary["verified"])
      @email = env["omniauth.auth"]["info"]["email"]
    end

    login
  end

  def google_oauth2
    if(env["omniauth.auth"]["extra"]["raw_info"]["email_verified"])
      @email = env["omniauth.auth"]["info"]["email"]
    end

    login
  end

  def myusa
    @email = env["omniauth.auth"]["info"]["email"]
    login
  end

  def persona
    @email = env["omniauth.auth"]["info"]["email"]
    login
  end

  private

  def login
    if @email.present?
      @admin = Admin.where(:username => @email).first
    end

    if @admin
      @admin.last_sign_in_provider = env["omniauth.auth"]["provider"]
      @admin.email = env["omniauth.auth"]["info"]["email"]
      @admin.name = env["omniauth.auth"]["info"]["name"]
      @admin.save!

      sign_in_and_redirect(:admin, @admin)
    else
      flash[:error] = %(The account for '#{@email}' is not authorized to access the admin. Please <a href="#{ApiUmbrellaConfig[:contact_url]}">contact us</a> for further assistance.).html_safe

      redirect_to new_admin_session_path
    end
  end

  def after_omniauth_failure_path_for(scope)
    new_admin_session_path
  end
end
