class ApplicationController < ActionController::Base
  protect_from_forgery

  def datatables_sort
    sort = []

    i = 0

    # rubocop:disable LiteralInCondition
    while true
      column_index = params["iSortCol_#{i}"]
      break if(column_index.nil?)

      column = params["mDataProp_#{column_index}"]
      order = params["sSortDir_#{i}"]
      sort << { column => order }

      i += 1
    end
    # rubocop:enable LiteralInCondition

    sort
  end

  def datatables_sort_array
    datatables_sort.map { |sort| sort.to_a.flatten }
  end
end
