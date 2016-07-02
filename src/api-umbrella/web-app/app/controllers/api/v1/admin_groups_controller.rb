class Api::V1::AdminGroupsController < Api::V1::BaseController
  respond_to :json

  skip_after_filter :verify_authorized, :only => [:index]

  def index
    @admin_groups = policy_scope(AdminGroup).order_by(datatables_sort_array)

    if(params[:order].blank?)
      @admin_groups = @admin_groups.order_by(:name.asc)
    end

    if(params[:start].present?)
      @admin_groups = @admin_groups.skip(params[:start].to_i)
    end

    if(params[:length].present?)
      @admin_groups = @admin_groups.limit(params[:length].to_i)
    end

    if(params[:search] && params[:search][:value].present?)
      @admin_groups = @admin_groups.or([
        { :name => /#{Regexp.escape(params[:search][:value])}/i },
      ])
    end

    @admin_groups_count = @admin_groups.count
    @admin_groups = @admin_groups.to_a.select { |group| Pundit.policy!(pundit_user, group).show? }
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

  def destroy
    @admin_group = AdminGroup.find(params[:id])
    authorize(@admin_group)
    @admin_group.destroy
    respond_with(:api_v1, @admin_group, :root => "admin_group")
  end

  private

  def save!
    authorize(@admin_group) unless(@admin_group.new_record?)
    @admin_group.assign_attributes(params[:admin_group], :as => :admin)
    authorize(@admin_group)
    @admin_group.save
  end
end
