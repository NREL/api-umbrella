require "elasticsearch/persistence/model"

class LogItem
  include Elasticsearch::Persistence::Model

  index_name "api-umbrella-logs-write-2015-01"
  document_type "log"

  attribute :api_key, String
  attribute :gatekeeper_denied_code, String
  attribute :request_accept_encoding, String
  attribute :request_at, Time
  attribute :request_hierarchy, Array
  attribute :request_host, String
  attribute :request_ip, String
  attribute :request_ip_city, String
  attribute :request_ip_country, String
  attribute :request_ip_region, String
  attribute :request_method, String
  attribute :request_path, String
  attribute :request_query, Hash
  attribute :request_scheme, String
  attribute :request_size, Integer
  attribute :request_url, String
  attribute :request_url_query, String
  attribute :request_user_agent, String
  attribute :request_user_agent_family, String
  attribute :request_user_agent_type, String
  attribute :response_age, Integer
  attribute :response_content_length, Integer
  attribute :response_content_type, String
  attribute :response_server, String
  attribute :response_size, Integer
  attribute :response_status, Integer
  attribute :response_time, Integer
  attribute :user_email, String
  attribute :user_id, String
  attribute :user_registration_source, String

  def save!
    self.save || raise("Failed to save log")
  end
end
