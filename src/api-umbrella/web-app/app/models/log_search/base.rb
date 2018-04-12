class LogSearch::Base
  attr_accessor :query, :query_options
  attr_reader :client, :start_time, :end_time, :interval, :region, :country, :state

  CASE_SENSITIVE_FIELDS = [
    "api_key",
    "request_ip_city",
  ].freeze

  UPPERCASE_FIELDS = [
    "request_ip_country",
    "request_ip_region",
  ].freeze

  def self.policy_class
    # Set the Pundit policy class to be the same for all LogSearch::Base child
    # classes.
    LogSearchPolicy
  end

  def initialize(options = {})
    @options = options
    @start_time = options[:start_time]
    unless(@start_time.kind_of?(Time))
      @start_time = Time.zone.parse(@start_time)
    end

    @end_time = options[:end_time]
    unless(@end_time.kind_of?(Time))
      @end_time = Time.zone.parse(@end_time).end_of_day
    end

    if(@end_time > Time.zone.now)
      @end_time = Time.zone.now
    end

    @options[:query_timeout] ||= 90

    @interval = options[:interval]
    @region = options[:region]
    @query = {}
    @query_options = {}
  end

  def aggregate_by_region!
    case(@region)
    when "world"
      aggregate_by_country!
    when "US"
      @country = @region
      aggregate_by_country_regions!(@region)
    when /^(US)-([A-Z]{2})$/
      @country = Regexp.last_match[1]
      @state = Regexp.last_match[2]
      aggregate_by_us_state_cities!(@country, @state)
    else
      @country = @region
      aggregate_by_country_cities!(@region)
    end
  end

  def aggregate_by_country!
    aggregate_by_region_field!(:request_ip_country)
  end

  def none!
    @none = true
  end
end
