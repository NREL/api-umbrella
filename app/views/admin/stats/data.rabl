node :hits do
  @hits.map do |time, count|
    {
      :c => [
        { :v => time },
        { :v => count, :f => number_with_delimiter(count) },
      ]
    }
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
