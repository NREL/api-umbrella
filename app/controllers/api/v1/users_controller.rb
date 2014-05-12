class Api::V1::UsersController < Api::V1::BaseController
  respond_to :json

  skip_before_filter :authenticate_admin!, :only => [:create]
  before_filter :authenicate_creator_api_key_role, :only => [:create]

  def show
    @api_user = ApiUser.find(params[:id])
  end

  def create
    # Wildcard CORS header to allow the signup form to be embedded anywhere.
    headers["Access-Control-Allow-Origin"] = "*"

    @api_user = ApiUser.new
    save!

    respond_to do |format|
      if(@api_user.save)
        if(params[:user][:send_welcome_email])
          ApiUserMailer.delay(:queue => "mailers").signup_email(@api_user)
        end

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

  # To create users, don't require an admin user, so the signup form can be
  # embedded on other sites. Instead, allow API keys with a
  # "api-umbrella-key-creator" role to also create users.
  #
  # This assumes API Umbrella is sitting in front and controlling access to
  # this API with roles and other mechanisms (such as referer checking) to
  # control signup access.
  def authenicate_creator_api_key_role
    unless(admin_signed_in?)
      api_key_roles = request.headers['X-Api-Roles'].to_s.split(",")
      unless(api_key_roles.include?("api-umbrella-key-creator"))
        render(:json => { :error => "You need to sign in or sign up before continuing." }, :status => :unauthorized)
        return false
      end
    end
  end
end
