class Api::V1::ApiScopesController < Api::V1::BaseController
  respond_to :json

  skip_after_filter :verify_authorized, :only => [:index]

  def index
    @api_scopes = policy_scope(ApiScope).order_by(datatables_sort_array)

    if(params[:order].blank?)
      @api_scopes = @api_scopes.order_by(:name.asc)
    end

    if(params[:start].present?)
      @api_scopes = @api_scopes.skip(params[:start].to_i)
    end

    if(params[:length].present?)
      @api_scopes = @api_scopes.limit(params[:length].to_i)
    end

    if(params[:search] && params[:search][:value].present?)
      @api_scopes = @api_scopes.or([
        { :name => /#{params[:search][:value]}/i },
        { :host => /#{params[:search][:value]}/i },
        { :path_prefix => /#{params[:search][:value]}/i },
      ])
    end
  end

  def show
    @api_scope = ApiScope.find(params[:id])
    authorize(@api_scope)
  end

  def create
    @api_scope = ApiScope.new
    save!
    respond_with(:api_v1, @api_scope, :root => "api_scope")
  end

  def update
    @api_scope = ApiScope.find(params[:id])
    save!
    respond_with(:api_v1, @api_scope, :root => "api_scope")
  end

  def destroy
    @api_scope = ApiScope.find(params[:id])
    authorize(@api_scope)
    @api_scope.destroy
    respond_with(:api_v1, @api_scope, :root => "api_scope")
  end

  private

  def save!
    @api_scope.assign_attributes(params[:api_scope], :as => :admin)
    authorize(@api_scope)
    @api_scope.save
  end
end
