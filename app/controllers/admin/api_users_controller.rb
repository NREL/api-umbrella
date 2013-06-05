class Admin::ApiUsersController < Admin::BaseController
  set_tab :users
  add_crumb("Users") { }

  def index
    @api_users = ApiUser.desc(:created_at).page(params[:page])

    add_crumb "API Users"
  end
end
