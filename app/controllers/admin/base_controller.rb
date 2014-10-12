class Admin::BaseController < ApplicationController
  before_filter :authenticate_admin!
  skip_after_filter :verify_authorized, :only => [:empty]

  layout "admin"

  def empty
    render(:text => "", :layout => true)
  end
end
