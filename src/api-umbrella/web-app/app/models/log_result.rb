class LogResult
  def self.factory(search, raw_result)
    case(search)
    when LogSearch::ElasticSearch
      LogResult::ElasticSearch.new(search, raw_result)
    when LogSearch::Kylin
      LogResult::Kylin.new(search, raw_result)
    when LogSearch::Postgresql
      LogResult::Postgresql.new(search, raw_result)
    end
  end
end
