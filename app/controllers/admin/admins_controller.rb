class Admin::AdminsController < Admin::BaseController
  def index
    limit = params["iDisplayLength"].to_i
    limit = 10 if(limit == 0)

    @admins = Admin
      .order_by(datatables_sort_array)
      .skip(params["iDisplayStart"].to_i)
      .limit(limit)

    if(params["sSearch"].present?)
      @admins = @admins.or([
        { :first_name => /#{params["sSearch"]}/i },
        { :last_name => /#{params["sSearch"]}/i },
        { :email => /#{params["sSearch"]}/i },
        { :username => /#{params["sSearch"]}/i },
        { :authentication_token => /#{params["sSearch"]}/i },
        { :_id => /#{params["sSearch"]}/i },
      ])
    end
  end
end
