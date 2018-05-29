class LogSearch
  def self.factory(adapter, options = {})
    case(adapter)
    when "elasticsearch"
      LogSearch::ElasticSearch.new(options)
    end
  end
end
