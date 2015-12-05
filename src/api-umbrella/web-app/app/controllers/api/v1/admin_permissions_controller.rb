class Api::V1::AdminPermissionsController < Api::V1::BaseController
  respond_to :json

  skip_after_filter :verify_authorized, :only => [:index]

  def index
    @admin_permissions = AdminPermission.sorted.all.to_a
    respond_with(:api_v1, @admin_permissions, :root => "admin_permissions")
  end
end
