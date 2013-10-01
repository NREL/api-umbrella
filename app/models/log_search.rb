require "elasticsearch_config"

class LogSearch
  attr_accessor :query, :query_options
  attr_reader :server, :start_time, :end_time, :interval, :region, :country, :state

  def initialize(options = {})
    @server = Stretcher::Server.new(ElasticsearchConfig.server, :logger => Rails.logger)

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

    @interval = options[:interval]
    @region = options[:region]

    @query = {
      :query => {
        :filtered => {
          :query => {
            :match_all => {},
          },
          :filter => {
            :and => [],
          },
        },
      },
      :sort => [
        { :request_at => :desc },
      ],
      :facets => {}
    }

    @query_options = {
      :size => 0,
      :ignore_indices => "missing",
    }
  end

  def result
    raw_result = @server.index(indexes.join(",")).search(@query_options, @query)
    @result = LogResult.new(self, raw_result)
  end

  def search!(query_string)
    if(query_string.present?)
      @query[:query][:filtered][:query] = {
        :query_string => {
          :query => query_string
        },
      }
    end
  end

  def limit!(size)
    @query_options[:size] = size
  end

  def filter_by_date_range!
    @query[:query][:filtered][:filter][:and] << {
      :range => {
        :request_at => {
          :from => @start_time.iso8601,
          :to => @end_time.iso8601,
        },
      },
    }
  end

  def filter_by_request_path!(request_path)
    @query[:query][:filtered][:filter][:and] << {
      :term => {
        :request_path => request_path,
      },
    }
  end

  def filter_by_api_key!(api_key)
    @query[:query][:filtered][:filter][:and] << {
      :term => {
        :api_key => api_key,
      },
    }
  end

  def filter_by_user!(user_email)
    @query[:query][:filtered][:filter][:and] << {
      :term => {
        :user => {
          :user_email => user_email,
        },
      },
    }
  end

  def facet_by_interval!
    @query[:facets][:interval_hits] = {
      :date_histogram => {
        :field => "request_at",
        :interval => @interval,
        :all_terms => true,
        :time_zone => Time.zone.name,
        :pre_zone_adjust_large_interval => true,
      },
    }
  end

  def facet_by_region!
    case(@region)
    when "world"
      facet_by_country!
    when "US"
      @country = @region
      facet_by_country_regions!(@region)
    when /^(US)-([A-Z]{2})$/
      @country = $1
      @state = $2
      facet_by_us_state_cities!(@country, @state)
    else
      @country = @region
      facet_by_country_cities!(@region)
    end
  end

  def facet_by_country!
    @query[:facets][:regions] = {
      :terms => {
        :field => "request_ip_country",
        :size => 250,
      },
    }
  end

  def facet_by_country_regions!(country)
    @query[:query][:filtered][:filter][:and] << {
      :term => { :request_ip_country => country },
    }

    @query[:facets][:regions] = {
      :terms => {
        :field => "request_ip_region",
        :size => 250,
      },
    }
  end

  def facet_by_us_state_cities!(country, state)
    @query[:query][:filtered][:filter][:and] << {
      :term => { :request_ip_country => country },
    }
    @query[:query][:filtered][:filter][:and] << {
      :term => { :request_ip_region => state },
    }

    @query[:facets][:regions] = {
      :terms => {
        :field => "request_ip_city",
        :size => 250,
      },
    }
  end

  def facet_by_country_cities!(country)
    @query[:query][:filtered][:filter][:and] << {
      :term => { :request_ip_country => country },
    }

    @query[:facets][:regions] = {
      :terms => {
        :field => "request_ip_city",
        :size => 250,
      },
    }
  end

  def facet_by_term!(term, size)
    @query[:facets][term.to_sym] = {
      :terms => {
        :field => term.to_s,
        :size => size,
      },
    }
  end

  def facet_by_users!(size)
    facet_by_term!(:user_email, size)
  end

  def facet_by_response_status!(size)
    facet_by_term!(:response_status, size)
  end

  def facet_by_response_content_type!(size)
    facet_by_term!(:response_content_type, size)
  end

  def facet_by_request_method!(size)
    facet_by_term!(:request_method, size)
  end

  def facet_by_request_ip!(size)
    facet_by_term!(:request_ip, size)
  end

  def facet_by_request_user_agent_family!(size)
    facet_by_term!(:request_user_agent_family, size)
  end

  private

  def indexes
    unless @indexes
      date_range = @start_time.utc.to_date..@end_time.utc.to_date
      @indexes = date_range.map { |date| "api-umbrella-logs-#{date.strftime("%Y-%m")}" }
      @indexes.uniq!
    end

    @indexes
  end
end
