class Admin::Admins::OmniauthCallbacksController < Devise::OmniauthCallbacksController
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
