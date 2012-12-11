class Admin::Admins::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  # For the developer strategy, simply find or create a new admin account with
  # whatever login details they give. This is not for use on production.
  def developer
    omniauth = env["omniauth.auth"]
    @admin = Admin.where(:username => omniauth["uid"]).first
    @admin ||= Admin.new(:username => omniauth["uid"])
    @admin.apply_omniauth(omniauth)
    @admin.save!
    sign_in(:admin, @admin)
    redirect_to admin_path
  end

  def cas
    omniauth = env["omniauth.auth"]
    @admin = Admin.where(:username => omniauth["uid"]).first
    if @admin
      @admin.apply_omniauth(omniauth)
      @admin.save!
      sign_in_and_redirect(:admin, @admin)
    else
      redirect_to root_path
    end
  end
end
