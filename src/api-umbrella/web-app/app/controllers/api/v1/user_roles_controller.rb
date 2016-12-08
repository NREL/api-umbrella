class Api::V1::UserRolesController < Api::V1::BaseController
  skip_after_action :verify_authorized, :only => [:index]

  def index
    @roles = ApiUserRole.all
    @roles.select! { |role| ApiUserRolePolicy.new(current_admin, role).show? }
    @roles.map! { |role| { :id => role } }

    render(:json => { "user_roles" => @roles })
  end
end
