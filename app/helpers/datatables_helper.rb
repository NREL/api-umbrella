# Methods relating to Datatables input handling
module DatatablesHelper
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

  # convert from ?param[0]=a&param[1]=b to ?param[]=a&param[]=b
  def param_index_array(key)
    as_array = []
    if params[key].is_a?(Array)
      as_array = params[key]
    elsif params[key].is_a?(Hash)
      upper_bound = params[key].length - 1
      (0..upper_bound).each { |idx|
        if params[key].has_key?(idx.to_s)
          as_array << params[key][idx.to_s]
        end
      }
    end
    as_array
  end

  # Parse the column request from a datatables query
  def datatables_columns
    columns = self.param_index_array(:columns)
    columns = columns.select{ |col| col[:data] }
    columns.map { |col| {
      name: (col[:name] || '-').to_s,
      field: col[:data].to_s
    }}
  end

  # Set download headers and join arrays
  def csv_output(results, columns)
    requested_fields = columns.map{|c| c[:field]}
    send_file_headers!(disposition: "attachment")
    self.response_body = CSV.generate { |csv|
      csv << columns.map{|c| c[:name]}
      results.each { |result|
        result = requested_fields.map{|field| result[field]}
        result = result.map{|cell| cell.is_a?(Array) ? cell.join(",") : cell }
        csv << result
      }
    }
  end

  # Include only the requested columns
  def respond_to_datatables(results)
    columns = self.datatables_columns
    requested_fields = columns.map{|c| c[:field]}
    results = results.map{|result|
      hash = result.serializable_hash
      hash.select{|k,v| requested_fields.include? k}
    }
    respond_to do |format|
      format.csv { self.csv_output(results, columns) }
      format.json
    end
  end

end
