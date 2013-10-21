class Admin::ConfigController < Admin::BaseController
  set_tab :config

  def show
    if(ConfigVersion.needs_publishing?)
      @published_config = YAML.dump(ConfigVersion.last_config)
      @new_config = YAML.dump(ConfigVersion.current_config)
    end
  end

  def create
    ConfigVersion.publish!

    flash[:success] = "Successfully published configuration... Changes should be live in a few seconds..."
    redirect_to(admin_config_publish_path)
  end
end
