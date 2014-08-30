class Admin::AdminScopesController < Admin::BaseController
  def index
    limit = params["iDisplayLength"].to_i
    limit = 10 if(limit == 0)

    @admin_scopes = AdminScope
      .order_by(datatables_sort_array)
      .skip(params["iDisplayStart"].to_i)
      .limit(limit)

    if(params["sSearch"].present?)
      @admin_scopes = @admin_scopes.or([
        { :name => /#{params["sSearch"]}/i },
        { :host => /#{params["sSearch"]}/i },
        { :path_prefix => /#{params["sSearch"]}/i },
        { :_id => /#{params["sSearch"]}/i },
      ])
    end
  end
end
