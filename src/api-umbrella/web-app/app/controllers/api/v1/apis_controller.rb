class Api::V1::ApisController < Api::V1::BaseController
  respond_to :json

  skip_after_filter :verify_authorized, :only => [:index]

  def index
    @apis = policy_scope(Api).order_by(datatables_sort_array)

    if(params[:start].present?)
      @apis = @apis.skip(params["start"].to_i)
    end

    if(params[:length].present?)
      @apis = @apis.limit(params["length"].to_i)
    end

    if(params["search"] && params["search"]["value"].present?)
      @apis = @apis.or([
        { :name => /#{params["search"]["value"]}/i },
        { :frontend_host => /#{params["search"]["value"]}/i },
        { :backend_host => /#{params["search"]["value"]}/i },
        { :"url_matches.backend_prefix" => /#{params["search"]["value"]}/i },
        { :"url_matches.frontend_prefix" => /#{params["search"]["value"]}/i },
        { :"servers.host" => /#{params["search"]["value"]}/i },
        { :_id => /#{params["search"]["value"]}/i },
      ])
    end

    @apis_count = @apis.count
    @apis = @apis.to_a.select { |api| Pundit.policy!(pundit_user, api).show? }
  end

  def show
    @api = Api.find(params[:id])
    authorize(@api)
    respond_with(:api_v1, @api, :root => "api")
  end

  def create
    @api = Api.new
    save!
    respond_with(:api_v1, @api, :root => "api")
  end

  def update
    @api = Api.find(params[:id])
    save!
    respond_with(:api_v1, @api, :root => "api")
  end

  def destroy
    @api = Api.find(params[:id])
    authorize(@api)
    @api.destroy
    respond_with(:api_v1, @api, :root => "api")
  end

  def move_after
    @api = Api.find(params[:id])
    authorize(@api)

    if(params[:move_after_id].present?)
      after_api = Api.find(params[:move_after_id])
      if(after_api)
        authorize(after_api)
        @api.move_after(after_api)
      end
    else
      @api.move_to_beginning
    end

    @api.save
    respond_with(:api_v1, @api, :root => "api")
  end

  private

  def save!
    @api.assign_nested_attributes(params[:api], :as => :admin)
    authorize(@api)

    @api.save
  end
end
