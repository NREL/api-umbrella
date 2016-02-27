require "active_record"

class LogSearchSql
  attr_accessor :query, :query_options
  attr_reader :client, :start_time, :end_time, :interval, :region, :country, :state, :result_processors

  CASE_SENSITIVE_FIELDS = [
    "api_key",
    "request_ip_country",
    "request_ip_region",
    "request_ip_city",
  ]

  LEGACY_FIELDS = {
    "request_scheme" => "request_url_scheme",
    "request_host" => "request_url_host",
    "request_path" => "request_url_path",
    "response_time" => "timer_response",
    "backend_response_time" => "timer_backend_response",
    "internal_gatekeeper_time" => "timer_internal",
    "proxy_overhead" => "timer_proxy_overhead",
    "gatekeeper_denied_code" => "denied_reason",
    "imported" => "log_imported",
  }

  FIELD_TYPES = {
    "response_status" => :int,
  }

  def initialize(options = {})
    @sequel = Sequel.connect("mock://postgresql")

    @client = Elasticsearch::Client.new({
      :hosts => ApiUmbrellaConfig[:elasticsearch][:hosts],
      :logger => Rails.logger
    })

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
      :select => [],
      :where => [],
      :group_by => [],
      :order_by => [],
    }

    @query_options = {
      :size => 0,
      :ignore_unavailable => "missing",
      :allow_no_indices => true,
    }

    @result_processors = []
  end

  def result
    sql = "SELECT #{@query[:select].join(", ")} FROM api_umbrella_logs"

    if(@query[:where].present?)
      sql << " WHERE #{@query[:where].map { |where| "(#{where})" }.join(" AND ")}"
    end

    if(@query[:group_by].present?)
      sql << " GROUP BY #{@query[:group_by].join(", ")}"
    end

    if(@query[:order_by].present?)
      sql << " ORDER BY #{@query[:order_by].join(", ")}"
    end

    conn = Faraday.new(:url => "http://kylin.host") do |faraday|
      #faraday.request  :logger
      faraday.response :logger
      faraday.adapter  Faraday.default_adapter  # make requests with Net::HTTP
      faraday.basic_auth "ADMIN", "KYLIN"
    end

    Rails.logger.info(sql)
    response = conn.post do |req|
      req.url "/kylin/api/query"
      req.headers["Content-Type"] = "application/json"
      req.body = MultiJson.dump({
        :acceptPartial => false,
        :project => "api_umbrella",
        :sql => sql,
      })
    end

    if(response.status != 200)
      Rails.logger.error(response.body)
      raise "Error"
    end

    raw_result = MultiJson.load(response.body)

    @result = LogResultSql.new(self, raw_result)
  end

  def permission_scope!(scopes)
    filter = {
      :bool => {
        :should => []
      },
    }

    scopes.each do |scope|
      filter[:bool][:should] << scope
    end

    @query[:query][:filtered][:filter][:bool][:must] << filter
  end

  def search_type!(search_type)
    @query_options[:search_type] = search_type
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

  def query!(query)
    if(query.kind_of?(String) && query.present?)
      query = MultiJson.load(query)
    end

    if(query.present?)
      filters = []
      query["rules"].each do |rule|
        filter = {}
        Rails.logger.info("RULE: #{rule.inspect}")

        field = rule["field"]
        if(LEGACY_FIELDS[field])
          field = LEGACY_FIELDS[field]
        end

        filter = nil
        operator = nil
        value = rule["value"]

        if(!CASE_SENSITIVE_FIELDS.include?(rule["field"]) && value.kind_of?(String))
          value.downcase!
        end

        if(value.present?)
          case(FIELD_TYPES[field])
          when :int
            value = Integer(value)
          when :double
            value = Float(value)
          end
        end

        case(field)
        when "request_method"
          value.upcase!
        end

        case(rule["operator"])
        when "equal"
          operator = "="
        when "not_equal"
          operator = "<>"
        when "begins_with"
          operator = "LIKE"
          value = "#{value}%"
        when "not_begins_with"
          operator = "NOT LIKE"
          value = "#{value}%"
        when "contains"
          operator = "LIKE"
          value = "%#{value}%"
        when "not_contains"
          operator = "NOT LIKE"
          value = "%#{value}%"
        when "is_null"
          operator = "IS NULL"
          value = nil
        when "is_not_null"
          operator = "IS NOT NULL"
          value = nil
        when "less"
          operator = "<"
        when "less_or_equal"
          operator = "<="
        when "greater"
          operator = ">"
        when "greater_or_equal"
          operator = ">="
        when "between"
          values = rule["value"].map { |v| v.to_f }.sort
          filter = "#{@sequel.quote_identifier(field)} >= #{@sequel.literal(values[0])} AND #{@sequel.quote_identifier(field)} <= #{@sequel.literal(values[1])}"
        else
          raise "unknown filter operator: #{rule["operator"]} (rule: #{rule.inspect})"
        end

        unless(filter)
          filter = "#{@sequel.quote_identifier(field)} #{operator}"
          unless(value.nil?)
            filter << " #{@sequel.literal(value)}"
          end
        end

        filters << filter
      end
      Rails.logger.info("FILTERS: #{filters.inspect}")

      if(filters.present?)
        where = filters.map { |where| "(#{where})" }
        if(query["condition"] == "OR")
          @query[:where] << where.join(" OR ")
        else
          @query[:where] << where.join(" AND ")
        end
      end
    end
  end

  def offset!(from)
    @query_options[:from] = from
  end

  def limit!(size)
    @query_options[:size] = size
  end

  def sort!(sort)
    @query[:sort] = sort
  end

  def exclude_imported!
    @query[:query][:filtered][:filter][:bool][:must_not] << {
      :exists => {
        :field => "imported",
      },
    }
  end

  def filter_by_date_range!
    @query[:where] << @sequel.literal(Sequel.lit("request_at_year >= :start_time_year AND request_at_month >= :start_time_month AND request_at_date >= :start_time_date AND request_at_year <= :end_time_year AND request_at_month <= :end_time_month AND request_at_date <= :end_time_date", {
      :start_time_year => @start_time.year,
      :start_time_month => @start_time.month,
      :start_time_date => @start_time.strftime("%Y-%m-%d"),
      :end_time_year => @end_time.year,
      :end_time_month => @end_time.month,
      :end_time_date => @end_time.strftime("%Y-%m-%d"),
    }))
  end

  def filter_by_request_path!(request_path)
    @query[:query][:filtered][:filter][:bool][:must] << {
      :term => {
        :request_path => request_path,
      },
    }
  end

  def filter_by_api_key!(api_key)
    @query[:query][:filtered][:filter][:bool][:must] << {
      :term => {
        :api_key => api_key,
      },
    }
  end

  def filter_by_user!(user_email)
    @query[:query][:filtered][:filter][:bool][:must] << {
      :term => {
        :user => {
          :user_email => user_email,
        },
      },
    }
  end

  def filter_by_user_ids!(user_ids)
    @query[:query][:filtered][:filter][:bool][:must] << {
      :terms => {
        :user_id => user_ids,
      },
    }
  end

  def aggregate_by_drilldown!(prefix, size = 0)
    @query[:aggregations][:drilldown] = {
      :terms => {
        :field => "request_hierarchy",
        :size => size,
        :include => "^#{Regexp.escape(prefix)}.*",
      },
    }
  end

  def aggregate_by_drilldown_over_time!(prefix)
    @query[:query][:filtered][:filter][:bool][:must] <<                 {
      :prefix => {
        :request_hierarchy => prefix,
      },
    }

    @query[:aggregations][:top_path_hits_over_time] = {
      :terms => {
        :field => "request_hierarchy",
        :size => 10,
        :include => "^#{Regexp.escape(prefix)}.*",
      },
      :aggregations => {
        :drilldown_over_time => {
          :date_histogram => {
            :field => "request_at",
            :interval => @interval,
            :time_zone => Time.zone.name,
            :pre_zone_adjust_large_interval => true,
            :min_doc_count => 0,
            :extended_bounds => {
              :min => @start_time.iso8601,
              :max => @end_time.iso8601,
            },
          },
        },
      },
    }

    @query[:aggregations][:hits_over_time] = {
      :date_histogram => {
        :field => "request_at",
        :interval => @interval,
        :time_zone => Time.zone.name,
        :pre_zone_adjust_large_interval => true,
        :min_doc_count => 0,
        :extended_bounds => {
          :min => @start_time.iso8601,
          :max => @end_time.iso8601,
        },
      },
    }
  end

  def aggregate_by_interval!
    @query[:aggregations][:hits_over_time] = {
      :date_histogram => {
        :field => "request_at",
        :interval => @interval,
        :time_zone => Time.zone.name,
        :pre_zone_adjust_large_interval => true,
        :min_doc_count => 0,
        :extended_bounds => {
          :min => @start_time.iso8601,
          :max => @end_time.iso8601,
        },
      },
    }
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

  def aggregate_by_region_field!(field)
    @query[:aggregations][:regions] = {
      :terms => {
        :field => field.to_s,
        :size => 500,
      },
    }

    @query[:aggregations][:missing_regions] = {
      :missing => {
        :field => field.to_s,
      },
    }
  end

  def aggregate_by_country!
    aggregate_by_region_field!(:request_ip_country)
  end

  def aggregate_by_country_regions!(country)
    @query[:query][:filtered][:filter][:bool][:must] << {
      :term => { :request_ip_country => country },
    }

    aggregate_by_region_field!(:request_ip_region)
  end

  def aggregate_by_us_state_cities!(country, state)
    @query[:query][:filtered][:filter][:bool][:must] << {
      :term => { :request_ip_country => country },
    }
    @query[:query][:filtered][:filter][:bool][:must] << {
      :term => { :request_ip_region => state },
    }

    aggregate_by_region_field!(:request_ip_city)
  end

  def aggregate_by_country_cities!(country)
    @query[:query][:filtered][:filter][:bool][:must] << {
      :term => { :request_ip_country => country },
    }

    aggregate_by_region_field!(:request_ip_city)
  end

  def aggregate_by_term!(field, size)
    @query[:aggregations]["top_#{field.to_s.pluralize}"] = {
      :terms => {
        :field => field.to_s,
        :size => size,
        :shard_size => size * 4,
      },
    }

    @query[:aggregations]["value_count_#{field.to_s.pluralize}"] = {
      :value_count => {
        :field => field.to_s,
      },
    }

    @query[:aggregations]["missing_#{field.to_s.pluralize}"] = {
      :missing => {
        :field => field.to_s,
      },
    }
  end

  def aggregate_by_cardinality!(field)
    @query[:aggregations]["unique_#{field.to_s.pluralize}"] = {
      :cardinality => {
        :field => field.to_s,
        :precision_threshold => 100,
      },
    }
  end

  def aggregate_by_users!(size)
    aggregate_by_term!(:user_email, size)
    aggregate_by_cardinality!(:user_email)
  end

  def aggregate_by_request_ip!(size)
    aggregate_by_term!(:request_ip, size)
    aggregate_by_cardinality!(:request_ip)
  end

  def aggregate_by_user_stats!(options = {})
    @query[:select] << "COUNT(*) AS hits"
    @query[:select] << "MAX(request_at) AS last_request_at"
    @query[:select] << "user_id"
    @query[:group_by] << "user_id"

    if(options[:order])
      if(options[:order]["_count"] == "asc")
        @query[:order_by] << "hits ASC"
      elsif(options[:order]["_count"] == "desc")
        @query[:order_by] << "hits DESC"
      elsif(options[:order]["last_request_at"] == "asc")
        @query[:order_by] << "last_request_at ASC"
      elsif(options[:order]["last_request_at"] == "desc")
        @query[:order_by] << "last_request_at DESC"
      end
    end

    @result_processors << Proc.new do |result|
      buckets = []
      result.raw_result["results"].each do |row|
        last_request_at = Time.at(row[result.column_indexes["last_request_at"]].to_i / 1000.0)
        buckets << {
          "key" => row[result.column_indexes["user_id"]],
          "doc_count" => row[result.column_indexes["hits"]].to_i,
          "last_request_at" => {
            "value" => row[result.column_indexes["last_request_at"]].to_f,
            "value_as_string" => Time.at(row[result.column_indexes["last_request_at"]].to_i / 1000.0).iso8601,
          },
        }
      end
      Rails.logger.info("PROC BUCKETS: #{buckets.inspect}")

      result.raw_result["aggregations"] ||= {}
      result.raw_result["aggregations"]["user_stats"] ||= {}
      result.raw_result["aggregations"]["user_stats"]["buckets"] = buckets
    end
  end

  def aggregate_by_response_time_average!
    @query[:select] << "AVG(timer_response)"
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
