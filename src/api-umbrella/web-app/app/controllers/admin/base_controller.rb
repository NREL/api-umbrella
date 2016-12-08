class Admin::BaseController < ApplicationController
  before_action :authenticate_admin!
  after_action :verify_authorized
  skip_after_action :verify_authorized, :only => [:empty]
end
