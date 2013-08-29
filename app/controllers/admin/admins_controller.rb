class Admin::AdminsController < Admin::BaseController
  set_tab :users

  add_crumb "Admin Accounts", :admin_admins_path
  add_crumb "New Admin", :only => [:new, :create]
  add_crumb "Edit Admin", :only => [:edit, :update]

  def index
    @admins = Admin.page(params[:page])
  end

  def new
    @admin = Admin.new
  end

  def edit
    @admin = Admin.find(params[:id])
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
