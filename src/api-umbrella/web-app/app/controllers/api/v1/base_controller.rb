class Api::V1::BaseController < ApplicationController
  # API requests won't pass CSRF tokens, so don't reject requests without them.
  protect_from_forgery :with => :null_session

  # Try authenticating from an admin token (for direct API access).
  before_action :authenticate_admin_from_token!

  # If no admin token is present, authenticate normally with Devise from a
  # session (so this API can be used from within the web admin tool).
  before_action :authenticate_admin!

  after_action :verify_authorized

  rescue_from Pundit::NotAuthorizedError, :with => :user_not_authorized

  private

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

    record.errors.to_hash.each do |field, field_messages|
      field_messages.each do |message|
        full_message = record.errors.full_message(field, message)
        full_message[0] = full_message[0].upcase

        response[:errors] << {
          :code => "INVALID_INPUT",
          :message => message,
          :field => field,
          :full_message => full_message,
        }
      end
    end

    response
  end
end
