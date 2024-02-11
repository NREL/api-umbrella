class LogItem
  include ActiveAttr::Model

  mattr_accessor :client

  attribute :_id
  attribute :api_backend_id
  attribute :api_backend_resolved_host
  attribute :api_backend_response_code_details
  attribute :api_backend_response_flags
  attribute :api_key
  attribute :gatekeeper_denied_code
  attribute :request_accept
  attribute :request_accept_encoding
  attribute :request_at
  attribute :request_connection
  attribute :request_content_type
  attribute :request_hierarchy
  attribute :request_host
  attribute :request_ip
  attribute :request_ip_city
  attribute :request_ip_country
  attribute :request_ip_region
  attribute :request_method
  attribute :request_origin
  attribute :request_path
  attribute :request_query
  attribute :request_referer
  attribute :request_scheme
  attribute :request_size
  attribute :request_url_query
  attribute :request_user_agent
  attribute :request_user_agent_family
  attribute :request_user_agent_type
  attribute :response_age
  attribute :response_cache
  attribute :response_cache_flags
  attribute :response_content_encoding
  attribute :response_content_length
  attribute :response_content_type
  attribute :response_custom1
  attribute :response_custom2
  attribute :response_custom3
  attribute :response_server
  attribute :response_size
  attribute :response_status
  attribute :response_time
  attribute :response_transfer_encoding
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
      :sort => "_doc",
      :scroll => "2m",
      :size => 1000,
      :body => {
        :query => {
          :match_all => {},
        },
      },
    }
    result = self.client.search(opts)
    loop do
      hits = result["hits"]["hits"]
      break if hits.empty?

      hits.each do |hit|
        bulk_request << { :delete => { :_index => hit["_index"], :_type => hit["_type"], :_id => hit["_id"] } }
      end

      result = self.client.scroll(:scroll_id => result["_scroll_id"], :scroll => "2m")
    end

    self.client.clear_scroll(:scroll_id => result["_scroll_id"])

    # Perform the bulk delete of all records in this index.
    unless bulk_request.empty?
      self.client.bulk :body => bulk_request
    end

    self.refresh_indices!
  end

  def serializable_hash
    hash = super

    cleaned_path = hash["request_path"].gsub(%r{//+}, "/")
    cleaned_path.gsub!(%r{/$}, "")
    cleaned_path.gsub!(%r{^/}, "")
    path_parts = cleaned_path.split("/", 6)

    if $config["opensearch"]["template_version"] < 2
      hash["request_url"] = "#{hash.fetch("request_scheme")}://#{hash.fetch("request_host")}#{hash.fetch("request_path")}"
      if hash["request_query"]
        hash["request_url"] << "?#{hash.fetch("request_query")}"
      end
    end

    if !hash["request_hierarchy"] || $config["opensearch"]["template_version"] >= 2
      hash["request_hierarchy"] = []
      host_level = hash["request_host"]
      if !path_parts.empty?
        host_level += "/"
      end
      hash["request_url_hierarchy_level0"] = host_level
      hash["request_hierarchy"] << "0/#{host_level}"

      path_tree = "/"
      path_parts.each_with_index do |path_level, index|
        if index + 1 < path_parts.length
          path_level += "/"
        end

        hash["request_url_hierarchy_level#{index + 1}"] = path_level

        path_tree = "#{path_tree}#{path_level}"
        path_token = "#{index + 1}/#{hash["request_host"]}#{path_tree}"
        hash["request_hierarchy"] << path_token
      end
    end

    if($config["opensearch"]["template_version"] >= 2)
      hash.delete("request_hierarchy")
      hash.delete("request_query")
    end

    hash
  end

  def save
    index_time = self.request_at
    if(index_time.kind_of?(Integer))
      index_time = Time.at(index_time / 1000.0).utc
    end

    prefix = "#{$config.fetch("opensearch").fetch("index_name_prefix")}-logs"
    index_name = "#{prefix}-v#{$config["opensearch"]["template_version"]}-all"

    self.client.index({
      :index => index_name,
      :id => self._id,
      :body => self.serializable_hash.except("_id"),
    })
  end

  def save!
    self.save || raise("Failed to save log")
  end
end
