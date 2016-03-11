class LogSearch
  def self.factory(options = {})
    case(ApiUmbrellaConfig[:analytics][:adapter])
    when "elasticsearch"
      LogSearch::Elasticsearch.new(options)
    when "kylin"
      LogSearch::Kylin.new(options)
    when "postgresql"
      LogSearch::Postgresql.new(options)
    end
  end
end
