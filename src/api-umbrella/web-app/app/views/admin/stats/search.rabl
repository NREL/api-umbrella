object false

extends "admin/stats/_hits_over_time"

node :stats do
  {
    :total_hits => @result.total,
    :total_users => @result.aggregations ? @result.aggregations.fetch("unique_user_emails").fetch("value") : 0,
    :total_ips => @result.aggregations ? @result.aggregations.fetch("unique_request_ips").fetch("value") : 0,
    :average_response_time => @result.aggregations ? @result.aggregations.fetch("response_time_average").fetch("value") : nil,
  }
end

node :aggregations do
  {
    :users => aggregation_result(:user_email),
    :ips => aggregation_result(:request_ip),
  }
end
