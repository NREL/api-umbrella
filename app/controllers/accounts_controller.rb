class AccountsController < ApplicationController
  respond_to :html

  def new
    @user = ApiUser.new
  end

  def create
    @user = ApiUser.find_or_initialize_by(:email => params[:api_user][:email], :website => params[:api_user][:website])
    @user.attributes = params[:api_user]

    # Safe safely to be absolutely positive the save succeeded.
    if @user.safely.save
      respond_with @user do |format|
        format.html do
          render
        end
      end
    else
      respond_with @user
    end
  end

  def terms
  end
end
