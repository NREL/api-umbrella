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
end
