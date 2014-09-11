object false

node :region_field do
  @search.query[:aggregations][:regions][:terms][:field]
end

node :regions do
  rows = @result.aggregations["regions"]["buckets"].map do |bucket|
    {
      :id => bucket["key"],
      :name => region_name(bucket["key"]),
      :hits => bucket["doc_count"],
    }
  end

  if(@result.aggregations["missing_regions"]["doc_count"] > 0)
    rows << {
      :id => "missing",
      :name => "Unknown",
      :hits => @result.aggregations["missing_regions"]["doc_count"],
    }
  end

  rows
end

node :map_regions do
  @result.aggregations["regions"]["buckets"].map do |bucket|
    {
      :c => region_location_columns(bucket) + [
        { :v => bucket["doc_count"], :f => number_with_delimiter(bucket["doc_count"]) },
      ]
    }
  end
end

node :map_breadcrumbs do
  @result.map_breadcrumbs
end
