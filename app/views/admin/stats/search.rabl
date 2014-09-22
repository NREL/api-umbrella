object false

extends "admin/stats/_hits_over_time"

node :stats do
  {
    :total_hits => @result.total,
    :total_users => @result.aggregations["unique_user_emails"]["value"],
    :total_ips => @result.aggregations["unique_request_ips"]["value"],
    :average_response_time => @result.aggregations["response_time_average"]["value"],
  }
end

node :aggregations do
  {
    :users => aggregation_result(:user_email),
    :ips => aggregation_result(:request_ip),
  }
end
