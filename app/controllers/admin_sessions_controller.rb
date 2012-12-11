class AdminSessionsController < Devise::SessionsController
  def new
    redirect_to(admin_omniauth_authorize_path(:provider => "developer"))
  end
end
