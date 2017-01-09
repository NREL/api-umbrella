class Admin::RegistrationsController < Devise::RegistrationsController
  before_action :first_time_setup

  protected

  def build_resource(hash = nil)
    super
    # Make the first admin a superuser on initial setup.
    self.resource.superuser = true
    self.resource
  end

  private

  def first_time_setup
    unless(Admin.needs_first_account?)
      flash[:notice] = "An initial admin account already exists."
      redirect_to admin_path
    end
  end
end
