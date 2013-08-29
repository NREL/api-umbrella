class Admin::ApisController < Admin::BaseController
  set_tab :apis

  def index
    @apis = Api.desc(:sort_order).desc(:_id).all

    respond_to do |format|
      format.json { render :json => { :apis => @apis } }
    end
  end

  def show
    @api = Api.find(params[:id])

    respond_to do |format|
      format.json { render :json => @api.to_json(:root => "api") }
    end
  end

  def create
    @api = Api.new
    save!
  end

  def update
    @api = Api.find(params[:id])
    save!
  end

  private

  def save!
    params[:api][:servers_attributes] = params[:api].delete(:servers) || []
    params[:api][:url_matches_attributes] = params[:api].delete(:url_matches) || []
    params[:api][:rewrites_attributes] = params[:api].delete(:rewrites) || []
    params[:api][:rate_limits_attributes] = params[:api].delete(:rate_limits) || []

    @api.attributes = params[:api]
    @api.save!
  end
end
