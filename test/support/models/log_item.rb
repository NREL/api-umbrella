#require "elasticsearch/persistence/model"

class LogItem
  include ActiveAttr::Model

  mattr_accessor :client
  mattr_accessor :index_name do
    "api-umbrella-logs-write-2015-01"
  end

  attribute :_id
  attribute :api_key
  attribute :gatekeeper_denied_code
  attribute :request_accept_encoding
  attribute :request_at
  attribute :request_hierarchy
  attribute :request_host
  attribute :request_ip
  attribute :request_ip_city
  attribute :request_ip_country
  attribute :request_ip_region
  attribute :request_method
  attribute :request_path
  attribute :request_scheme
  attribute :request_size
  attribute :request_url_query
  attribute :request_user_agent
  attribute :request_user_agent_family
  attribute :request_user_agent_type
  attribute :response_age
  attribute :response_content_length
  attribute :response_content_type
  attribute :response_server
  attribute :response_size
  attribute :response_status
  attribute :response_time
  attribute :user_email
  attribute :user_id
  attribute :user_registration_source

  def self.refresh_index!
    self.client.indices.refresh(:index => self.index_name)
  end

  def save
    self.class.client.index({
      :index => self.class.index_name,
      :type => "log",
      :id => self._id,
      :body => self.serializable_hash.except("_id"),
    })
  end

  def save!
    self.save || raise("Failed to save log")
  end
end
