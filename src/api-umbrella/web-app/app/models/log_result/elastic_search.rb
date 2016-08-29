class LogResult::ElasticSearch < LogResult::Base
  def bulk_each
    scroll_id = raw_result["_scroll_id"]
    while(scroll = @search.client.scroll(:scroll_id => scroll_id, :scroll => "10m")) # rubocop:disable Lint/AssignmentInCondition
      scroll_id = scroll["_scroll_id"]
      hits = scroll["hits"]["hits"]

      # Break when elasticsearch returns empty hits (we've reached the end).
      break if hits.empty?

      hits.each do |hit|
        yield hit["_source"]
      end
    end
  end
end
