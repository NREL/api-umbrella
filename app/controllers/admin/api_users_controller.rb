class Admin::ApiUsersController < Admin::BaseController
  set_tab :users
  add_crumb("Users") { }

  def index
    @api_users = ApiUser.desc(:created_at).page(params[:page])

    add_crumb "API Users"
  end

  def edit
    @api_user = ApiUser.find(params[:id])

    add_crumb "API Users", admin_api_users_path
    add_crumb "Edit User"
  end

  def update
    @api_user = ApiUser.find(params[:id])
    @api_user.assign_attributes(params[:api_user], :as => :admin)
    @api_user.save!

    flash[:success] = "Successfully updated user account"
    redirect_to(admin_api_users_path)
  rescue Mongoid::Errors::Validations
    render(:action => "edit")
  end
end
