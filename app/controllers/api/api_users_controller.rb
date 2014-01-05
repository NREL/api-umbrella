class Api::ApiUsersController < ApplicationController
  def validate
    @user = ApiUser.where(:api_key => params[:id]).first

    @response = { :status => "invalid" }
    if @user
      @response[:status] = "valid"
    end

    respond_to do |format|
      format.json { render :json => @response }
      format.xml { render :xml => @response }
    end
  end

  def show
    @user = ApiUser.where(:api_key => params[:id]).first

    respond_to do |format|
      format.json { render :json => @user }
      format.xml { render :xml => @user }
    end
  end

  def create
    @user = ApiUser.find_or_initialize_by(:email => params[:email], :website => params[:website], :registration_source => params[:registration_source])
    @user.no_domain_signup = true

    # Only allow the use description to be set if something is actually passed
    # in. This ensures that use descriptions from existing users aren't
    # overwritten unless something is actually provided.
    if(params[:use_description].blank?)
      params.delete(:use_description)
    end

    @user.attributes = params

    # Safe safely to be absolutely positive the save succeeded.
    if @user.with(:safe => true).save
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
