class Admin::BaseController < ApplicationController
  before_filter :authenticate_admin!

  layout "admin"

  # Clear out any root crumbs from ApplicationController (that's for the public
  # site).
  clear_crumbs

  def empty
    render(:text => "", :layout => true)
  end
end
