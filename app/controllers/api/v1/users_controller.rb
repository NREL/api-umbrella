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

    respond_with(:api_v1, @api_user, :root => "user")
  end

  def update
    @api_user = ApiUser.find(params[:id])
    save!
    respond_with(:api_v1, @api_user, :root => "user")
  end

  private

  def save!
    @api_user.no_domain_signup = true
    @api_user.assign_nested_attributes(params[:user], :as => :admin)

    if(@api_user.new_record?)
      @api_user.registration_source = "web_admin"
    end

    @api_user.save
  end
end
