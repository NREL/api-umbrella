class Admin::AdminsController < Admin::BaseController
  set_tab :users
  add_crumb("Users") { }

  def index
    @admins = Admin.page(params[:page])

    add_crumb "Admin Accounts"
  end

  def new
    @admin = Admin.new

    add_crumb "Admin Accounts", admin_admins_path
    add_crumb "Add New Account"
  end

  def edit
    @admin = Admin.find(params[:id])

    add_crumb "Admin Accounts", admin_admins_path
    add_crumb "Edit Account"
  end

  def create
    @admin = Admin.new(params[:admin])
    @admin.save!

    flash[:success] = "Successfully added admin account"
    redirect_to(admin_admins_path)
  rescue Mongoid::Errors::Validations
    render(:action => "new")
  end

  def update
    @admin = Admin.find(params[:id])
    @admin.update_attributes!(params[:admin])

    flash[:success] = "Successfully updated admin account"
    redirect_to(admin_admins_path)
  rescue Mongoid::Errors::Validations
    render(:action => "edit")
  end

  def destroy
    @admin = Admin.find(params[:id])
    @admin.destroy
    redirect_to(admin_admins_path)
  end
end
