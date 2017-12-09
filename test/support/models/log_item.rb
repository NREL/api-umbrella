#require "elasticsearch/persistence/model"

class LogItem
  include ActiveAttr::Model

  mattr_accessor :client

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
  attribute :request_query
  attribute :request_scheme
  attribute :request_size
  attribute :request_url
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

  def self.refresh_indices!
    self.client.indices.refresh(:index => "_all")
  end

  def self.clean_indices!
    # Refresh all data, so the search results contain all the data for this
    # index.
    self.refresh_indices!

    # Since ElasticSearch 2 removed the delete by query functionality, search
    # for all the records and build up a series of delete commands for each
    # individual record.
    #
    # While not the most efficient way to bulk delete things, we don't want to
    # completely drop the index, since that might remove mappings that only get
    # created on API Umbrella startup.
    bulk_request = []
    opts = {
      :index => "_all",
      :type => "log",
      :sort => "_doc",
      :scroll => "2m",
      :size => 1000,
      :body => {
        :query => {
          :match_all => {},
        },
      },
    }
    if($config["elasticsearch"]["api_version"] < 2)
      opts.delete(:sort)
      opts[:search_type] = "scan"
    end
    result = self.client.search(opts)
    while true
      hits = result["hits"]["hits"]
      break if hits.empty?
      hits.each do |hit|
        bulk_request << { :delete => { :_index => hit["_index"], :_type => hit["_type"], :_id => hit["_id"] } }
      end

      result = self.client.scroll(:scroll_id => result["_scroll_id"], :scroll => "2m")
    end

    # Perform the bulk delete of all records in this index.
    unless bulk_request.empty?
      self.client.bulk :body => bulk_request
    end

    self.refresh_indices!
  end

  def serializable_hash
    hash = super

    if($config["log_template_version"] >= 2)
      hash.delete("request_query")
      hash.delete("request_url")
    end

    hash
  end

  def save
    index_time = self.request_at
    if(index_time.kind_of?(Fixnum))
      index_time = Time.at(index_time / 1000.0)
    end

    index_name = "api-umbrella-logs-write-#{index_time.utc.strftime("%Y-%m")}"

    self.class.client.index({
      :index => index_name,
      :type => "log",
      :id => self._id,
      :body => self.serializable_hash.except("_id"),
    })
  end

  def save!
    self.save || raise("Failed to save log")
  end
end
