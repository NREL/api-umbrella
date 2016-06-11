class ElasticsearchHelper
  def self.clean_es_indices(indices)
    indices.each do |month|
      result = LogItem.gateway.client.search :index => "api-umbrella-logs-#{month}",
            :body => {
              :query => {
                :match_all => {}
              },
              :size => 1000,
            }
      bulk_request = result["hits"]["hits"].map do |hit|
        { :delete => { :_index => hit["_index"], :_type => hit["_type"], :_id => hit["_id"] } }
      end

      unless bulk_request.empty?
        LogItem.gateway.client.bulk :body => bulk_request
      end
    end
  end
end
