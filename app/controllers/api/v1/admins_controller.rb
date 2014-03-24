class Api::V1::AdminsController < Api::V1::BaseController
  respond_to :json

  def show
    @admin = Admin.find(params[:id])
  end

  def create
    @admin = Admin.new
    save!
    respond_with(:api_v1, @admin, :root => "admin")
  end

  def update
    @admin = Admin.find(params[:id])
    save!
    respond_with(:api_v1, @admin, :root => "admin")
  end

  private

  def save!
    @admin.assign_attributes(params[:admin], :as => :admin)
    @admin.save
  end
end
