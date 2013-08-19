class Admin::BaseController < ApplicationController
  before_filter :authenticate_admin!

  layout "admin"

  def empty
    render(:text => "", :layout => true)
  end
end
