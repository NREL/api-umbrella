class Api::V1::UserRolesController < Api::V1::BaseController
  respond_to :json

  skip_after_filter :verify_authorized, :only => [:index]

  def index
    @roles = ApiUserRole.all
    @roles.select! { |role| ApiUserRolePolicy.new(current_admin, role).show? }
    @roles.map! { |role| { :id => role } }

    respond_with(:api_v1, @roles, :root => "user_roles")
  end
end
