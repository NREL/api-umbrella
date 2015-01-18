require "elasticsearch/persistence/model"

class LogItem
  include Elasticsearch::Persistence::Model

  index_name "api-umbrella-logs-2015-01"

  attribute :api_key, String
  attribute :backend_response_time, Float
  attribute :internal_gatekeeper_time, Float
  attribute :internal_response_time, Float
  attribute :proxy_overhead, Float
  attribute :request_accept, String
  attribute :request_at, Time
  attribute :request_hierarchy, Array
  attribute :request_host, String
  attribute :request_ip, String
  attribute :request_method, String
  attribute :request_path, String
  attribute :request_query, Hash
  attribute :request_scheme, String
  attribute :request_size, Integer
  attribute :request_url, String
  attribute :request_user_agent, String
  attribute :request_user_agent_family, String
  attribute :request_user_agent_type, String
  attribute :response_age, Integer
  attribute :response_content_length, Integer
  attribute :response_content_type, String
  attribute :response_server, String
  attribute :response_size, Integer
  attribute :response_status, Integer
  attribute :response_time, Float
  attribute :user_email, String
  attribute :user_id, String
  attribute :user_registration_source, String

  def save!
    self.save || raise("Failed to save log")
  end
end

FactoryGirl.define do
  factory :log_item do
    api_key "UfhkQUBgWQbJ0ZVqnJ4TvA7quGCZHYTFCXwSfOTQ"
    backend_response_time 0
    internal_gatekeeper_time 1.4
    internal_response_time 1.8
    proxy_overhead 3
    request_accept "*/*"
    request_at { Time.now }
    request_hierarchy ["0/127.0.0.1/", "1/127.0.0.1/hello"]
    request_host "127.0.0.1"
    request_ip "127.0.0.1"
    request_method "GET"
    request_path "/hello/"
    request_query({ "foo" => "bar" })
    request_scheme "http"
    request_size 140
    request_url "http://127.0.0.1/hello/?foo=bar"
    request_user_agent "ApacheBench/2.3"
    request_user_agent_family "AB (Apache Bench)"
    request_user_agent_type "Other"
    response_age 0
    response_content_length 14
    response_content_type "text/plain"
    response_server "nginx"
    response_size 243
    response_status 200
    response_time 3
    user_email "test@example.com"
    user_id "4199b260-ae76-463f-8395-d30de09c1540"
    user_registration_source "web_admin"
  end
end
