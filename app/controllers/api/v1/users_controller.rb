class Api::V1::UsersController < Api::V1::BaseController
  respond_to :json

  def show
    @api_user = ApiUser.find(params[:id])
  end

  def create
    @api_user = ApiUser.new
    save!

    if(@api_user.errors.blank? && params[:user][:send_welcome_email])
      ApiUserMailer.delay(:queue => "mailers").signup_email(@api_user)
    end

    respond_to do |format|
      if(@api_user.save)
        format.json { render("show", :status => :created, :location => api_v1_user_url(@api_user)) }
      else
        format.json { render(:json => errors_response(@api_user), :status => :unprocessable_entity) }
      end
    end
  end

  def update
    @api_user = ApiUser.find(params[:id])
    save!

    respond_to do |format|
      if(@api_user.save)
        format.json { render("show", :status => :ok, :location => api_v1_user_url(@api_user)) }
      else
        format.json { render(:json => errors_response(@api_user), :status => :unprocessable_entity) }
      end
    end
  end

  private

  def save!
    @api_user.no_domain_signup = true
    @api_user.assign_nested_attributes(params[:user], :as => :admin)

    if(@api_user.new_record?)
      @api_user.registration_source = "web_admin"
    end
  end
end
