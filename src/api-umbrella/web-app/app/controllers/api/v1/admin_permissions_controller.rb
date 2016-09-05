class Api::V1::AdminPermissionsController < Api::V1::BaseController
  skip_after_action :verify_authorized, :only => [:index]

  def index
    @admin_permissions = AdminPermission.sorted.all.to_a
    @admin_permissions.map! { |permission| permission.as_json }

    render(:json => { "admin_permissions" => @admin_permissions })
  end
end
