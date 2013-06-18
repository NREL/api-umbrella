node :hits do
  @hits.map do |time, count|
    {
      :c => [
        { :v => time , :f => formatted_interval_time(time) },
        { :v => count, :f => number_with_delimiter(count) },
      ]
    }
  end
end

if @regions
  node :region_field do
    @query[:facets][:regions][:terms][:field]
  end

  node :regions do
    rows = @regions.map do |term|
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
    @map_breadcrumbs
  end
end

node :results do
  @result.results.map do |result|
    result.except(:api_key, :_type, :_score, :_index)
  end
end


node :user_id do
  partial("admin/stats/facet", :object => false, :locals => { :facet => @result.facets[:user_id] })
end

node :response_status do
  partial("admin/stats/facet", :object => false, :locals => { :facet => @result.facets[:response_status] })
end

node :request_method do
  partial("admin/stats/facet", :object => false, :locals => { :facet => @result.facets[:request_method] })
end

node :request_ip do
  partial("admin/stats/facet", :object => false, :locals => { :facet => @result.facets[:request_ip] })
end

node :response_content_type do
  partial("admin/stats/facet", :object => false, :locals => { :facet => @result.facets[:response_content_type] })
end
