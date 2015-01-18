class Admin::Admins::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  # For the developer strategy, simply find or create a new admin account with
  # whatever login details they give. This is not for use on production.
  def developer
    unless(%w(development test).include?(Rails.env))
      raise "The developer OmniAuth strategy should not be used outside of development or test."
    end

    omniauth = request.env["omniauth.auth"]
    @admin = Admin.where(:username => omniauth["uid"]).first
    @admin ||= Admin.new({ :username => omniauth["uid"], :superuser => true }, :without_protection => true)
    @admin.apply_omniauth(omniauth)
    @admin.save!
    sign_in(:admin, @admin)
    redirect_to admin_path
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

  def myusa
    @email = request.env["omniauth.auth"]["info"]["email"]
    login
  end

  def persona
    @email = request.env["omniauth.auth"]["info"]["email"]
    login
  end

  private

  def login
    if @email.present?
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
      flash[:error] = %(The account for '#{@email}' is not authorized to access the admin. Please <a href="#{ApiUmbrellaConfig[:contact_url]}">contact us</a> for further assistance.).html_safe

      redirect_to new_admin_session_path
    end
  end

  def after_omniauth_failure_path_for(scope)
    new_admin_session_path
  end
end
