class Admin::ConfigController < Admin::BaseController
  def show
  end

  def create
    ConfigVersion.publish!

    flash[:success] = "Successfully published configuration... Changes should be live in a few seconds..."
    redirect_to(admin_config_publish_path)
  end
end
