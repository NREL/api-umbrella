class Api::V1::ConfigController < Api::V1::BaseController
  respond_to :json

  skip_after_action :verify_authorized, :only => [:pending_changes]

  def pending_changes
    @changes = ConfigVersion.pending_changes(pundit_user)
  end

  def publish
    active_config = ConfigVersion.active_config || {}
    new_config = active_config.deep_dup

    changes = false
    ["apis", "website_backends"].each do |category|
      new_config[category] ||= []
      next unless(params[:config].present? && params[:config][category].present?)

      params[:config][category].each do |record_id, record_params|
        next unless(record_params[:publish].to_s == "1")

        record = case(category)
                 when "apis"
                   Api.unscoped.find(record_id)
                 when "website_backends"
                   WebsiteBackend.unscoped.find(record_id)
                 end

        authorize(record, :publish?)
        changes = true

        if(record.kind_of?(Api))
          record.handle_transition_https_on_publish!
        end

        new_config[category].reject! { |data| data["_id"] == record_id }
        unless record.deleted_at?
          new_config[category] << record.attributes_hash
        end
      end
    end

    if changes
      new_config["apis"].sort_by! { |data| data["sort_order"].to_i }
      new_config["website_backends"].sort_by! { |data| data["frontend_host"].to_i }

      @config_version = ConfigVersion.publish!(new_config)
    else
      # If there were no changes, then we haven't authorized and anything. In
      # this case, skip Pundit's verify_authorized, since there's nothing to
      # actually check.
      skip_authorization

      @config_version = active_config
    end

    respond_with(:api_v1, @config_version, :root => "config_version", :location => api_v1_config_pending_changes_url)
  end
end
