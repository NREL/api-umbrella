object false

extends "admin/stats/_interval_hits"

node :stats do
  {
    :total_hits => @result.total,
    :total_users => @result.facets["total_user_email"]["terms"].length,
    :total_ips => @result.facets["total_request_ip"]["terms"].length,
    :average_response_time => @result.facets["response_time_stats"]["mean"],
  }
end

node :facets do
  {
    :users => facet_result(:user_email),
    :ips => facet_result(:request_ip),
    :content_types => facet_result(:response_content_type),
  }
end

node :logs do
  @result.documents.map do |log|
    log.except("api_key", "_type", "_score", "_index").merge({
      "request_url" => log["request_url"].gsub(%r{^.*://[^/]*}, "")
    })
  end
end
