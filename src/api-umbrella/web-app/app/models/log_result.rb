class LogResult
  def self.factory(search, raw_result)
    case(ApiUmbrellaConfig[:analytics][:adapter])
    when "elasticsearch"
      LogResult::ElasticSearch.new(search, raw_result)
    when "kylin"
      LogResult::Kylin.new(search, raw_result)
    when "postgresql"
      LogResult::Postgresql.new(search, raw_result)
    end
  end
end
