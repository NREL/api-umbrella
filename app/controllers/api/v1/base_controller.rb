class Api::V1::BaseController < ApplicationController
  # Try authenticating from an admin token (for direct API access).
  before_filter :authenticate_admin_from_token!

  # If no admin token is present, authenticate normally with Devise from a
  # session (so this API can be used from within the web admin tool).
  before_filter :authenticate_admin!

  private

  def authenticate_admin_from_token!
    admin_token = params[:admin_token].presence
    admin = admin_token && Admin.where(:authentication_token => admin_token.to_s).first

    if admin
      # Don't store the user on the session, so the token is required on every
      # request.
      sign_in(admin, :store => false)
    end
  end
end
