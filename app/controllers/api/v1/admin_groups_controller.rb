class Api::V1::AdminGroupsController < Api::V1::BaseController
  respond_to :json

  def index
    @admin_groups = AdminGroup.all
  end

  def show
    @admin_group = AdminGroup.find(params[:id])
  end

  def create
    @admin_group = AdminGroup.new
    save!
    respond_with(:api_v1, @admin_group, :root => "admin_group")
  end

  def update
    @admin_group = AdminGroup.find(params[:id])
    save!
    respond_with(:api_v1, @admin_group, :root => "admin_group")
  end

  private

  def save!
    @admin_group.assign_attributes(params[:admin_group], :as => :admin)
    @admin_group.save
  end
end
