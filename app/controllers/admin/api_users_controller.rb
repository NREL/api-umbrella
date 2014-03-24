class Admin::ApiUsersController < Admin::BaseController
  def index
    limit = params["iDisplayLength"].to_i
    limit = 10 if(limit == 0)

    @api_users = ApiUser
      .order_by(datatables_sort_array)
      .skip(params["iDisplayStart"].to_i)
      .limit(limit)

    if(params["sSearch"].present?)
      @api_users = @api_users.or([
        { :first_name => /#{params["sSearch"]}/i },
        { :last_name => /#{params["sSearch"]}/i },
        { :email => /#{params["sSearch"]}/i },
        { :api_key => /#{params["sSearch"]}/i },
        { :_id => /#{params["sSearch"]}/i },
      ])
    end
  end
end
