class Admin::ApisController < Admin::BaseController
  respond_to :json
  set_tab :config

  def index
    @apis = Api.sorted.all
    respond_with({ :apis => @apis })
  end

  def show
    @api = Api.find(params[:id])
    respond_with(:admin, @api, :root => "api")
  end

  def create
    @api = Api.new
    save!
    respond_with(:admin, @api, :root => "api")
  end

  def update
    @api = Api.find(params[:id])
    save!
    respond_with(:admin, @api, :root => "api")
  end

  def destroy
    @api = Api.find(params[:id])
    @api.destroy
    respond_with(:admin, @api, :root => "api")
  end

  private

  def save!
    @api.nested_attributes = params[:api]
    @api.save
  end
end
