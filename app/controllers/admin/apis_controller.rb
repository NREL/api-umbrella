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
    # The admin sends the complete API as a JSON representation of how it
    # should look. We have to do a bit of massaging to get the input in the
    # format accepts_nested_attributes_for expects for nested items.
    #
    # We could bypass this accepts_nested_attributes_for approach and just set
    # all our data directly, but that seems to mess up dirty tracking (since
    # all the nested objects get replaced with new objects, rather than
    # updating existing objects). This may not matter that much in reality, but
    # it seems to make the history tracking with Mongoid::Delorean misbehave.
    # However, if this accepts_nested_attributes_for business gets any uglier,
    # it might be worth looking into again.
    params[:api][:settings_attributes] = params[:api].delete(:settings) || {}
    [:servers, :url_matches, :sub_settings, :rewrites, :rate_limits].each do |collection|
      params[:api][:"#{collection}_attributes"] = params[:api].delete(collection) || []

      # Since the data posted is a full representation of the api, it doesn't
      # contain the special `_destroy` attribute accepts_nested_attributes_for
      # expects for removed items (they'll just be missing). So we need to
      # manually fill in the items that have been destroyed.
      ids_from_params = params[:api][:"#{collection}_attributes"].map { |collection_params| collection_params[:_id].to_s }
      @api.send(collection).each do |record|
        id = record._id.to_s
        if(!ids_from_params.include?(id))
          params[:api][:"#{collection}_attributes"] << {
            :_id => id,
            :_destroy => true,
          }
        end
      end
    end

    params[:api][:sub_settings_attributes].each do |sub_settings|
      sub_settings[:settings_attributes] = sub_settings.delete(:settings) || {}
    end

    @api.attributes = params[:api]
    @api.save
  end
end
