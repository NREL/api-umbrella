class Api::ApiUsersController < ApplicationController
  def create
    @user = ApiUser.find_or_initialize_by(:email => params[:email], :website => params[:website])
    @user.no_domain_signup = true

    # Only allow the use description to be set if something is actually passed
    # in. This ensures that use descriptions from existing users aren't
    # overwritten unless something is actually provided.
    if(params[:use_description].blank?)
      params.delete(:use_description)
    end

    @user.attributes = params

    # Safe safely to be absolutely positive the save succeeded.
    if @user.safely.save
      respond_to do |format|
        format.json { render :json => @user, :status => :created }
      end
    else
      respond_to do |format|
        format.json { render :json => @user, :status => :unprocessable_entity }
      end
    end
  end
end
