class Api::V1::AdminScopesController < Api::V1::BaseController
  respond_to :json

  def index
    @admin_scopes = AdminScope.all
  end

  def show
    @admin_scope = AdminScope.find(params[:id])
  end

  def create
    @admin_scope = AdminScope.new
    save!
    respond_with(:api_v1, @admin_scope, :root => "admin_scope")
  end

  def update
    @admin_scope = AdminScope.find(params[:id])
    save!
    respond_with(:api_v1, @admin_scope, :root => "admin_scope")
  end

  private

  def save!
    @admin_scope.assign_attributes(params[:admin_scope], :as => :admin)
    @admin_scope.save
  end
end
