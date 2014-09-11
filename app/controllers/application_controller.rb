class ApplicationController < ActionController::Base
  include Pundit
  protect_from_forgery

  def datatables_sort
    sort = []

    if(params[:order].present?)
      params[:order].each do |i, order|
        column_index = order[:column]
        column = params[:columns][column_index]
        column_name = column[:data]
        sort << { column_name => order[:dir] }
      end
    end

    sort
  end

  def datatables_sort_array
    datatables_sort.map { |sort| sort.to_a.flatten }
  end

  def pundit_user
    current_admin
  end
end
