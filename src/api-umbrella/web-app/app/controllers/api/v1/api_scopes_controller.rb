class Api::V1::ApiScopesController < Api::V1::BaseController
  respond_to :json

  skip_after_action :verify_authorized, :only => [:index]
  after_action :verify_policy_scoped, :only => [:index]

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
        { :name => /#{Regexp.escape(params[:search][:value])}/i },
        { :host => /#{Regexp.escape(params[:search][:value])}/i },
        { :path_prefix => /#{Regexp.escape(params[:search][:value])}/i },
        { :_id => params[:search][:value].downcase },
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
    authorize(@api_scope) unless(@api_scope.new_record?)
    @api_scope.assign_attributes(api_scope_params)
    authorize(@api_scope)
    @api_scope.save
  end

  def api_scope_params
    params.require(:api_scope).permit([
      :name,
      :host,
      :path_prefix,
    ])
  rescue => e
    logger.error("Parameters error: #{e}")
    ActionController::Parameters.new({}).permit!
  end
end
