class Admin::ApiUsersController < Admin::BaseController
  set_tab :users

  def index
    @api_users = ApiUser.desc(:created_at).page(params[:page])

    if(params[:search].present?)
      @api_users = @api_users.or([
        { :first_name => /#{params[:search]}/i },
        { :last_name => /#{params[:search]}/i },
        { :email => /#{params[:search]}/i },
        { :api_key => /#{params[:search]}/i },
      ])
    end

    add_crumb "API Users"
  end

  def new
    @api_user = ApiUser.new

    add_crumb "API Users", admin_api_users_path
    add_crumb "New User"
  end

  def edit
    @api_user = ApiUser.find(params[:id])

    add_crumb "API Users", admin_api_users_path
    add_crumb "Edit User"
  end

  def create
    @api_user = ApiUser.new
    save!

    flash[:success] = "Successfully created user account"
    redirect_to(admin_api_users_path)
  rescue Mongoid::Errors::Validations
    logger.info($!.inspect)
    logger.info(@api_user.errors.inspect)
    render(:action => "new")
  end

  def update
    @api_user = ApiUser.find(params[:id])
    save!

    flash[:success] = "Successfully updated user account"
    redirect_to(admin_api_users_path)
  rescue Mongoid::Errors::Validations
    render(:action => "edit")
  end

  private

  def save!
    @api_user.no_domain_signup = true;
    @api_user.assign_attributes(params[:api_user], :as => :admin)
    @api_user.save!
  end
end
