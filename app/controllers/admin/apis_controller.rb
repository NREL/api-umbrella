class Admin::ApisController < Admin::BaseController
  def index
    limit = params["iDisplayLength"].to_i
    limit = 10 if(limit == 0)

    @apis = Api
      .order_by(datatables_sort_array)
      .skip(params["iDisplayStart"].to_i)
      .limit(limit)

    if(params["sSearch"].present?)
      @apis = @apis.or([
        { :name => /#{params["sSearch"]}/i },
        { :frontend_host => /#{params["sSearch"]}/i },
        { :backend_host => /#{params["sSearch"]}/i },
        { :"url_matches.backend_prefix" => /#{params["sSearch"]}/i },
        { :"url_matches.frontend_prefix" => /#{params["sSearch"]}/i },
        { :"servers.host" => /#{params["sSearch"]}/i },
        { :_id => /#{params["sSearch"]}/i },
      ])
    end
  end
end
