class Admin::AdminGroupsController < Admin::BaseController
  def index
    limit = params["iDisplayLength"].to_i
    limit = 10 if(limit == 0)

    @admin_groups = AdminGroup
      .order_by(datatables_sort_array)
      .skip(params["iDisplayStart"].to_i)
      .limit(limit)

    if(params["sSearch"].present?)
      @admin_groups = @admin_groups.or([
        { :name => /#{params["sSearch"]}/i },
        { :scope_host => /#{params["sSearch"]}/i },
        { :scope_path => /#{params["sSearch"]}/i },
        { :_id => /#{params["sSearch"]}/i },
      ])
    end
  end
end
