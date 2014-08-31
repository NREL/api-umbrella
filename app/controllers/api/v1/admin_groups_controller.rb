class Api::V1::AdminGroupsController < Api::V1::BaseController
  respond_to :json

  skip_after_filter :verify_authorized, :only => [:index]

  def index
    @admin_groups = policy_scope(AdminGroup)
    @admin_groups = @admin_groups.to_a.select { |group| AdminGroupPolicy.new(pundit_user, group).show? }
  end

  def show
    @admin_group = AdminGroup.find(params[:id])
    authorize(@admin_group)
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
    authorize(@admin_group)
    @admin_group.save
  end
end
