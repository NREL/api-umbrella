class AdminSessionsController < Devise::SessionsController
  def new
    redirect_to("/admins/auth/cas")
  end
end
