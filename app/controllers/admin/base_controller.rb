class Admin::BaseController < ApplicationController
  before_filter :authenticate_admin!

  layout "admin"
end
