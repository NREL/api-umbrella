class Admin::SessionsController < Devise::SessionsController
  def new
  end

  def after_sign_out_path_for(resource_or_scope)
    admin_path
  end
end
