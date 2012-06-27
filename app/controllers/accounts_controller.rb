class AccountsController < ApplicationController
  add_crumb "Signup"

  def new
    @user = ApiUser.new
  end

  def create
    @user = ApiUser.find_or_initialize_by(:email => params[:api_user][:email], :website => params[:api_user][:website])
    @user.attributes = params[:api_user]

    # Safe safely to be absolutely positive the save succeeded.
    if @user.safely.save
      respond_to do |format|
        format.html
      end
    else
      respond_to do |format|
        format.html { render :new }
      end
    end
  end

  def terms
    render(:layout => "popup")
  end
end
