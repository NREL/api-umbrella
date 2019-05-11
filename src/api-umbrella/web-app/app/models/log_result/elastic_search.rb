class LogResult::ElasticSearch < LogResult::Base
  def bulk_each
    result = raw_result
    loop do
      hits = result["hits"]["hits"]
      break if hits.empty?

      hits.each do |hit|
        yield hit["_source"]
      end

      result = @search.client.scroll(:scroll_id => result["_scroll_id"], :scroll => "10m")
    end

    @search.client.clear_scroll(:scroll_id => result["_scroll_id"])
  end
end
