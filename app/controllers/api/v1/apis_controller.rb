class Api::V1::ApisController < Api::V1::BaseController
  respond_to :json

  def index
    @apis = Api.sorted.all
    respond_with({ :apis => @apis })
  end

  def show
    @api = Api.find(params[:id])
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
    @api.destroy
    respond_with(:api_v1, @api, :root => "api")
  end

  private

  def save!
    @api.assign_nested_attributes(params[:api], :as => :admin)
    @api.save
  end
end
