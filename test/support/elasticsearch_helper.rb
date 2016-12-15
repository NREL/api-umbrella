class ElasticsearchHelper
  def self.clean_es_indices(indices)
    indices.each do |month|
      client = LogItem.gateway.client

      # Flush all data, so the search results contain all the data for this
      # index.
      client.indices.flush(:index => "api-umbrella-logs-#{month}")

      # Since ElasticSearch 2 removed the delete by query functionality, search
      # for all the records and build up a series of delete commands for each
      # individual record.
      #
      # While not the most efficient way to bulk delete things, we don't want
      # to completely drop the index, since that might remove mappings that
      # only get created on API Umbrella startup.
      bulk_request = []
      result = client.search({
        :index => "api-umbrella-logs-#{month}",
        :search_type => "scan",
        :scroll => "2m",
        :size => 1000,
        :body => {
          :query => {
            :match_all => {},
          },
        },
      })
      while(result = client.scroll(:scroll_id => result["_scroll_id"], :scroll => "2m")) # rubocop:disable Lint/AssignmentInCondition
        hits = result["hits"]["hits"]
        break if hits.empty?
        hits.each do |hit|
          bulk_request << { :delete => { :_index => hit["_index"], :_type => hit["_type"], :_id => hit["_id"] } }
        end
      end

      # Perform the bulk delete of all records in this index.
      unless bulk_request.empty?
        client.bulk :body => bulk_request
      end

      client.indices.flush(:index => "api-umbrella-logs-#{month}")
    end
  end
end
