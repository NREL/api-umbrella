class Admin::ApisController < Admin::BaseController
  respond_to :json
  set_tab :config

  def index
    @apis = Api.desc(:sort_order).desc(:_id).all
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
    # Re-sort the incoming embedded arrays based on the virtual `sort_order`
    # attribute. We won't store this value since the embedded array implicitly
    # provides this sort value.
    [:url_matches, :sub_settings, :rewrites].each do |collection|
      if(params[:api][collection].present?)
        # The virtual `sort_order` attribute will only be present if the data
        # has been resorted by the user. Otherwise, we can just accept the
        # incoming array order as correct.
        if(params[:api][collection].first[:sort_order].present?)
          params[:api][collection].sort_by! { |p| p[:sort_order] }
        end

        params[:api][collection].each { |p| p.delete(:sort_order) }
      end
    end

    @api.attributes = params[:api]
    @api.save
  end
end
