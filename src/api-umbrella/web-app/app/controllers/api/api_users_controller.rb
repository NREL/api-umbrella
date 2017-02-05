class Api::ApiUsersController < ApplicationController
  # API requests won't pass CSRF tokens, so don't reject requests without them.
  protect_from_forgery :with => :null_session

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
end
