object false

node :region_field do
  @search.query[:facets][:regions][:terms][:field]
end

node :regions do
  rows = @result.facets[:regions][:terms].map do |term|
    {
      :c => region_location_columns(term) + [
        { :v => term[:count], :f => number_with_delimiter(term[:count]) },
      ]
    }
  end

  if @result.facets[:regions][:missing] > 0
    rows << {
      :c => region_location_columns(:term => "Unknown") + [
        { :v => @result.facets[:regions][:missing], :f => number_with_delimiter(@result.facets[:regions][:missing]) },
      ]
    }
  end

  rows
end

node :map_breadcrumbs do
  @result.map_breadcrumbs
end
