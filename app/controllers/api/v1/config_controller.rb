class Api::V1::ConfigController < Api::V1::BaseController
  respond_to :json

  skip_after_filter :verify_authorized, :only => [:pending]

  def pending
    @changes = ConfigVersion.pending_changes(pundit_user)
  end

  def publish
    active_config = ConfigVersion.active_config
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

    new_config["apis"].sort_by! do |data|
      created_at = data["created_at"]
      unless(created_at.kind_of?(Time))
        created_at = Time.parse(created_at.to_s)
      end

      created_at_desc = created_at.to_i * -1

      [data["sort_order"].to_i, created_at_desc]
    end

    @config_version = ConfigVersion.publish!(new_config)
    respond_with(:api_v1, @config_version, :root => "config_version", :location => api_v1_config_pending_url)
  end
end
