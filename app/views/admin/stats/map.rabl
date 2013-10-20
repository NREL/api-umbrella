object false

node :region_field do
  @search.query[:facets][:regions][:terms][:field]
end

node :regions do
  rows = @result.facets["regions"]["terms"].map do |term|
    {
      :id => term["term"],
      :name => region_name(term["term"]),
      :hits => term["count"],
    }
  end

  if @result.facets["regions"]["missing"] > 0
    rows << {
      :id => "missing",
      :name => "Unknown",
      :hits => @result.facets["regions"]["missing"],
    }
  end

  rows
end

node :map_regions do
  @result.facets["regions"]["terms"].map do |term|
    {
      :c => region_location_columns(term) + [
        { :v => term["count"], :f => number_with_delimiter(term["count"]) },
      ]
    }
  end
end

node :map_breadcrumbs do
  @result.map_breadcrumbs
end
