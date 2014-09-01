class Api::V1::ConfigController < Api::V1::BaseController
  respond_to :json

  skip_after_filter :verify_authorized, :only => [:pending_changes]

  def pending_changes
    @changes = ConfigVersion.pending_changes(pundit_user)
  end

  def publish
    active_config = ConfigVersion.active_config || {}
    new_config = active_config.deep_dup
    new_config["apis"] ||= []

    params[:config][:apis].each do |api_id, api_params|
      next unless(api_params[:publish].to_s == "1")

      api = Api.unscoped.find(api_id)
      authorize(api, :publish?)

      new_config["apis"].reject! { |data| data["_id"] == api_id }
      unless api.deleted_at?
        new_config["apis"] << api.attributes_hash
      end
    end

    new_config["apis"].sort_by! { |data| data["sort_order"].to_i }

    @config_version = ConfigVersion.publish!(new_config)
    respond_with(:api_v1, @config_version, :root => "config_version", :location => api_v1_config_pending_changes_url)
  end
end
