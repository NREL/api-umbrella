class Api::V1::BaseController < ApplicationController
  # Try authenticating from an admin token (for direct API access).
  before_action :authenticate_admin_from_token!

  # If no admin token is present, authenticate normally with Devise from a
  # session (so this API can be used from within the web admin tool).
  before_action :authenticate_admin!

  after_action :verify_authorized

  rescue_from Pundit::NotAuthorizedError, :with => :user_not_authorized

  private

  def authenticate_admin_from_token!
    admin_token = request.headers['X-Admin-Auth-Token'].presence
    admin = admin_token && Admin.where(:authentication_token => admin_token.to_s).first

    if admin
      # Don't store the user on the session, so the token is required on every
      # request.
      sign_in(admin, :store => false)

      # The normal userstamp before_action that set's the current admin fires
      # before we handle token authentication. To fix that, force the userstamp
      # model to pickup the current admin account after this token-based login.
      unless RequestStore.store[:current_userstamp_user]
        begin
          RequestStore.store[:current_userstamp_user] = current_admin
        rescue => e
          Rails.logger.warn("Unexpected error setting userstamp: #{e}")
        end
      end
    end
  end

  def user_not_authorized(exception)
    authorized_scopes_list = []
    if(current_admin)
      scopes = current_admin.api_scopes
      if(scopes.present?)
        scopes.each do |scope|
          authorized_scopes_list << "- #{scope.host}#{scope.path_prefix}"
        end
      end
    end

    message = I18n.t("errors.messages.admin_not_authorized", :authorized_scopes_list => authorized_scopes_list.sort.join("\n"))

    render(:json => {
      :errors => [{
        :code => "FORBIDDEN",
        :message => message,
      }],
    }, :status => :forbidden)
  end

  def errors_response(record)
    response = { :errors => [] }

    record.errors.each do |field, message|
      response[:errors] << {
        :code => "INVALID_INPUT",
        :message => message,
        :field => field,
        :full_message => record.errors.full_message(field, message),
      }
    end

    response
  end
end
