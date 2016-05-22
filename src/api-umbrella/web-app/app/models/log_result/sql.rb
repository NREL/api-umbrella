class LogResult::Sql < LogResult::Base
  def initialize(search, raw_result)
    super

    if(search.result_processors.present?)
      search.result_processors.each do |processor|
        processor.call(self)
      end
    end
  end

  def column_indexes(query_name)
    column_indexes = {}
    raw_result[query_name]["columnMetas"].each_with_index do |meta, index|
      column_indexes[meta["label"].downcase] = index
    end

    column_indexes
  end
end
