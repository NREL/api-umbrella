class Admin::ApisController < Admin::BaseController
  skip_after_filter :verify_authorized, :only => [:index]

  respond_to :json

  def index
    limit = params["iDisplayLength"].to_i
    limit = 10 if(limit == 0)

    @apis = policy_scope(Api)
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

    @apis = @apis.to_a.select! { |api| ApiPolicy.new(pundit_user, api).show? }
  end

  def move_to
    @api = Api.find(params[:id])
    @api.move_to(params[:move_to].to_i)
    @api.save
    respond_with(:admin, @api, :root => "api")
  end
end
