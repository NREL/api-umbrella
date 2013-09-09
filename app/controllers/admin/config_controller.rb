class Admin::ConfigController < Admin::BaseController
  def show
  end

  def create
    ConfigVersion.publish!
    redirect_to(admin_config_publish_path)
  end
end
