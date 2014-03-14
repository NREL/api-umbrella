class Admin::ApiUsersController < Admin::BaseController
  respond_to :json
  set_tab :users

  add_crumb "API Users", :admin_api_users_path
  add_crumb "New User", :only => [:new, :create]
  add_crumb "Edit User", :only => [:edit, :update]

  def index
    limit = params["iDisplayLength"].to_i
    limit = 10 if(limit == 0)

    @api_users = ApiUser
      .order_by(datatables_sort_array)
      .skip(params["iDisplayStart"].to_i)
      .limit(limit)

    if(params["sSearch"].present?)
      @api_users = @api_users.or([
        { :first_name => /#{params["sSearch"]}/i },
        { :last_name => /#{params["sSearch"]}/i },
        { :email => /#{params["sSearch"]}/i },
        { :api_key => /#{params["sSearch"]}/i },
        { :_id => /#{params["sSearch"]}/i },
      ])
    end
  end

  def show
    @api_user = ApiUser.find(params[:id])
  end

  def create
    @api_user = ApiUser.new
    save!

    if(@api_user.errors.blank? && params[:api_user][:send_welcome_email])
      ApiUserMailer.delay(:queue => "mailers").signup_email(@api_user)
    end

    respond_with(:admin, @api_user, :root => "api_user")
  end

  def update
    @api_user = ApiUser.find(params[:id])
    save!
    respond_with(:admin, @api_user, :root => "api_user")
  end

  private

  def save!
    @api_user.no_domain_signup = true
    @api_user.assign_nested_attributes(params[:api_user], :as => :admin)

    if(@api_user.new_record?)
      @api_user.registration_source = "web_admin"
    end

    @api_user.save
  end
end
