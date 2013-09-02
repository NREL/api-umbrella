class Admin::ApisController < Admin::BaseController
  respond_to :json
  set_tab :apis

  def index
    @apis = Api.desc(:sort_order).desc(:_id).all
    respond_with({ :apis => @apis })
  end

  def show
    @api = Api.find(params[:id])
    respond_with(@api, :root => "api")
  end

  def create
    @api = Api.new
    save!
    respond_with(@api, :root => "api")
  end

  def update
    @api = Api.find(params[:id])
    save!
    respond_with(@api, :root => "api")
  end

  private

  def save!
    params[:api][:servers_attributes] = params[:api].delete(:servers) || []
    params[:api][:url_matches_attributes] = params[:api].delete(:url_matches) || []
    params[:api][:sub_settings_attributes] = params[:api].delete(:sub_settings) || []
    params[:api][:rewrites_attributes] = params[:api].delete(:rewrites) || []
    params[:api][:rate_limits_attributes] = params[:api].delete(:rate_limits) || []

    @api.attributes = params[:api]
    @api.save
  end
end
