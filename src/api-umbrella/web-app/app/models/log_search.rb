class LogSearch
  def self.factory(adapter, options = {})
    case(adapter)
    when "elasticsearch"
      LogSearch::ElasticSearch.new(options)
    when "kylin"
      LogSearch::Kylin.new(options)
    when "postgresql"
      LogSearch::Postgresql.new(options)
    end
  end
end
