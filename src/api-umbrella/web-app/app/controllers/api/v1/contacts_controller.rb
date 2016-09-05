class Api::V1::ContactsController < Api::V1::BaseController
  skip_before_action :authenticate_admin!, :only => [:create]
  before_action :authenicate_contact_api_key_role, :only => [:create]
  skip_after_action :verify_authorized

  def create
    @contact = Contact.new(contact_params)

    respond_to do |format|
      if(@contact.deliver)
        format.json { render(:json => { :submitted => Time.now.utc }, :status => :ok) }
      else
        format.json { render(:json => errors_response(@contact), :status => :unprocessable_entity) }
      end
    end
  end

  private

  # To submit contact messages, don't require an admin user, so the contact
  # form can use this API. Instead, allow API keys with a
  # "api-umbrella-contact-form" role to submit here.
  def authenicate_contact_api_key_role
    unless(admin_signed_in?)
      api_key_roles = request.headers['X-Api-Roles'].to_s.split(",")
      unless(api_key_roles.include?("api-umbrella-contact-form"))
        render(:json => { :error => "You need to sign in or sign up before continuing." }, :status => :unauthorized)
        return false
      end
    end
  end

  def contact_params
    params.require(:contact).permit([
      :name,
      :email,
      :api,
      :subject,
      :message,
    ])
  rescue => e
    logger.error("Parameters error: #{e}")
    ActionController::Parameters.new({}).permit!
  end
end
