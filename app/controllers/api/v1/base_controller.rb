class Api::V1::BaseController < ApplicationController
  # Try authenticating from an admin token (for direct API access).
  before_filter :authenticate_admin_from_token!

  # If no admin token is present, authenticate normally with Devise from a
  # session (so this API can be used from within the web admin tool).
  before_filter :authenticate_admin!

  private

  def authenticate_admin_from_token!
    admin_token = request.headers['X-Admin-Auth-Token'].presence
    admin = admin_token && Admin.where(:authentication_token => admin_token.to_s).first

    if admin
      # Don't store the user on the session, so the token is required on every
      # request.
      sign_in(admin, :store => false)

      # The mongoid_userstamp plugin doesn't seem to pickup the current admin
      # user when we load via this token (something to do with callback
      # ordering?). To to fix that, force the userstamp model to pickup the
      # current admin account after this token-based login.
      unless Mongoid::Userstamp.current_user
        begin
          Mongoid::Userstamp.config.user_model.current = self.send(Mongoid::Userstamp.config.user_reader)
        rescue
          Rails.logger.warn("Unexpected error setting userstamp: #{$!}")
        end
      end
    end
  end
end
