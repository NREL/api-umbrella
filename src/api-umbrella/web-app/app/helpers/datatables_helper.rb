# Methods relating to Datatables input handling
module DatatablesHelper
  def datatables_sort
    sort = []
    columns = self.datatables_columns
    param_index_array(:order).each do |order|
      column_index = order[:column].to_i
      if columns.length > column_index
        field = columns[column_index][:field]
        sort << { field => order[:dir] }
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
      indexes = params[key].keys.sort_by { |k| k.to_i }
      indexes.each do |index|
        as_array << params[key][index]
      end
    elsif params.key?(key)
      as_array = [params[key]]
    end
    as_array
  end

  # Parse the column request from a datatables query
  def datatables_columns
    columns = self.param_index_array(:columns)
    columns = columns.select { |col| col[:data] }
    columns.map do |col|
      {
        :name => (col[:name] || '-').to_s,
        :field => col[:data].to_s,
      }
    end
  end

  # Set download headers and join arrays
  def csv_output(results, columns)
    requested_fields = columns.map { |c| c[:field] }
    CSV.generate do |csv|
      csv << columns.map { |c| c[:name] }
      results.each do |result|
        result = requested_fields.map { |field| result[field] }
        result = result.map { |cell| cell.is_a?(Array) ? cell.join(",") : cell }
        csv << result
      end
    end
  end

  # Include only the requested columns
  def respond_to_datatables(results, csv_filename)
    columns = self.datatables_columns
    requested_fields = columns.map { |c| c[:field] }
    results = results.map do |result|
      hash = result.serializable_hash
      hash.select { |k, v| requested_fields.include? k }
    end
    respond_to do |format|
      format.csv do
        send_file_headers!(:disposition => "attachment", :filename => csv_filename + ".csv")
        self.response_body = self.csv_output(results, columns)
      end
      format.json
    end
  end
end
