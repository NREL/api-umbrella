require("json")

class LogSearch::ElasticSearch < LogSearch::Base
  attr_reader :client, :drilldown_depth, :drilldown_parent

  def initialize(options = {})
    super

    @client = ::Elasticsearch::Client.new({
      :hosts => ApiUmbrellaConfig[:elasticsearch][:hosts],
      :logger => Rails.logger,
    })

    @query = {
      :query => {
        :bool => {
          :must => {
            :match_all => {},
          },
          :filter => {
            :bool => {
              :must => [],
              :must_not => [],
            },
          },
        },
      },
      :sort => [
        { :request_at => :desc },
      ],
      :aggregations => {},
      :size => 0,
    }

    @query_options = {
      :ignore_unavailable => true,
      :allow_no_indices => true,
    }

    if ApiUmbrellaConfig[:elasticsearch][:api_version] >= 7
      @query[:track_total_hits] = true
    end

    if(@options[:query_timeout])
      @query[:timeout] = "#{@options[:query_timeout]}s"
    end
  end

  def result
    # Starting in ElasticSearch 1.4, we need to explicitly remove the
    # aggregations if there aren't actually any present for scroll queries to
    # work.
    if @query[:aggregations] && @query[:aggregations].blank?
      @query.delete(:aggregations)
    end

    # When querying many indices (particularly if partitioning by day), we can
    # run into URL length limits with the default search approach, which
    # requires the indices be in the URL:
    # https://github.com/elastic/elasticsearch/issues/26360
    #
    # To sidestep this, we will perform most queries using the _msearch API,
    # which allows us to put the index names in the POST body, so it's not
    # subject to URL length limits.
    #
    # However, for scroll queries, the msearch API doesn't support this
    # (https://github.com/elastic/elasticsearch-php/issues/478#issuecomment-254321873),
    # so we must revert back to normal search mode for these queries. In the
    # event the URL length is too long, then we handle these scroll queries by
    # querying all indices using a wildcard. While slightly less efficient, this
    # should be better optimized in Elasticsearch 5+
    # (https://www.elastic.co/blog/instant-aggregations-rewriting-queries-for-fun-and-profit).
    indices = indexes.join(",")
    if @query_options[:scroll]
      # The default URL length limit for Elasticsearch is 4096 bytes, but
      # reduce the limit before truncating to the wildcard index name so
      # there's still room for other query params.
      if indices.length > 3700
        indices = "#{ApiUmbrellaConfig[:elasticsearch][:index_name_prefix]}-logs-*"
      end

      raw_result = @client.search(@query_options.merge({
        :index => indices,
        :body => @query,
      }))
    else
      query_options = @query_options.deep_dup.merge({
        :index => indices,
      })
      raw_result = @client.msearch(:body => [query_options, @query])
      if raw_result["responses"] && raw_result["responses"][0]
        raw_result = raw_result["responses"][0]
        if raw_result["_shards"] && raw_result["_shards"]["failures"].present?
          raise "Unsuccessful response"
        end
      end
    end

    if(raw_result["timed_out"])
      # Don't return partial results.
      raise "Elasticsearch request timed out"
    end

    @result = LogResult.factory(self, raw_result)
  end

  def permission_scope!(scopes)
    filter = {
      :bool => {
        :should => [],
      },
    }

    scopes["rules"].each do |rule|
      filter[:bool][:should] << parse_query_builder(rule)
    end

    @query[:query][:bool][:filter][:bool][:must] << filter
  end

  def search_type!(search_type)
    if(search_type == "count")
      @query[:size] = 0
    end
  end

  def search!(query_string)
    if(query_string.present?)
      @query[:query][:bool][:filter][:bool][:must] << {
        :query_string => {
          :query => query_string,
        },
      }
    end
  end

  def query!(query)
    if(query.kind_of?(String) && query.present?)
      query = MultiJson.load(query)
    end

    filter = parse_query_builder(query)
    if(filter.present?)
      @query[:query][:bool][:filter][:bool][:must] << filter
    end
  end

  def parse_query_builder(query)
    query_filter = nil

    if(query.present?)
      filters = []
      query["rules"].each do |rule|
        filter = {}

        if(CASE_SENSITIVE_FIELDS.exclude?(rule["field"]) && rule["value"].kind_of?(String))
          if(UPPERCASE_FIELDS.include?(rule["field"]))
            rule["value"] = rule["value"].upcase
          else
            rule["value"] = rule["value"].downcase
          end
        end

        case(rule["operator"])
        when "equal", "not_equal"
          filter = {
            :term => {
              rule["field"] => rule["value"],
            },
          }
        when "begins_with", "not_begins_with"
          filter = {
            :prefix => {
              rule["field"] => rule["value"],
            },
          }
        when "contains", "not_contains"
          filter = {
            :regexp => {
              rule["field"] => ".*#{Regexp.escape(rule["value"])}.*",
            },
          }
        when "is_null", "is_not_null"
          filter = {
            :exists => {
              "field" => rule["field"],
            },
          }
        when "less"
          filter = {
            :range => {
              rule["field"] => {
                "lt" => rule["value"].to_f,
              },
            },
          }
        when "less_or_equal"
          filter = {
            :range => {
              rule["field"] => {
                "lte" => rule["value"].to_f,
              },
            },
          }
        when "greater"
          filter = {
            :range => {
              rule["field"] => {
                "gt" => rule["value"].to_f,
              },
            },
          }
        when "greater_or_equal"
          filter = {
            :range => {
              rule["field"] => {
                "gte" => rule["value"].to_f,
              },
            },
          }
        when "between"
          values = rule["value"].map { |v| v.to_f }.sort
          filter = {
            :range => {
              rule["field"] => {
                "gte" => values[0],
                "lte" => values[1],
              },
            },
          }
        else
          raise "unknown filter operator: #{rule["operator"]} (rule: #{rule.inspect})"
        end

        if(rule["operator"] =~ /(^not|^is_null)/ && filter.present?)
          filter = { :bool => { :must_not => [filter] } }
        end

        filters << filter
      end

      if(filters.present?)
        condition = if(query["condition"] == "OR") then :should else :must end
        query_filter = {
          :bool => {
            condition => filters,
          },
        }
      end
    end

    query_filter
  end

  def offset!(from)
    @query[:from] = from
  end

  def limit!(size)
    @query[:size] = size
  end

  def sort!(sort)
    @query[:sort] = sort
  end

  def exclude_imported!
    @query[:query][:bool][:filter][:bool][:must_not] << {
      :exists => {
        :field => "imported",
      },
    }
  end

  def filter_by_date_range!
    @query[:query][:bool][:filter][:bool][:must] << {
      :range => {
        :request_at => {
          :from => @start_time.iso8601,
          :to => @end_time.iso8601,
        },
      },
    }
  end

  def filter_by_request_path!(request_path)
    @query[:query][:bool][:filter][:bool][:must] << {
      :term => {
        :request_path => request_path,
      },
    }
  end

  def filter_by_api_key!(api_key)
    @query[:query][:bool][:filter][:bool][:must] << {
      :term => {
        :api_key => api_key,
      },
    }
  end

  def filter_by_user!(user_email)
    @query[:query][:bool][:filter][:bool][:must] << {
      :term => {
        :user => {
          :user_email => user_email,
        },
      },
    }
  end

  def filter_by_user_ids!(user_ids)
    @query[:query][:bool][:filter][:bool][:must] << {
      :terms => {
        :user_id => user_ids,
      },
    }
  end

  def aggregate_by_drilldown!(prefix, size = nil)
    prefix_parts = prefix.split("/")
    @drilldown_prefix = prefix
    @drilldown_depth = prefix[0].to_i
    @drilldown_parent = []
    @drilldown_path_segments = []

    prefix_parts.each_with_index do |value, index|
      if index > 0
        @drilldown_path_segments << {
          :level => index - 1,
          :value => value,
        }

        if index <= @drilldown_depth
          @drilldown_parent << value
        end
      end
    end
    @drilldown_parent = File.join(@drilldown_parent)
    if @drilldown_parent == ""
      @drilldown_parent = nil
    end

    size ||= 1_000_000
    @query[:aggregations][:drilldown] = {
      :terms => {
        :size => size,
      },
    }

    if ApiUmbrellaConfig[:elasticsearch][:template_version] < 2
      @query[:query][:bool][:filter][:bool][:must] << {
        :prefix => {
          :request_hierarchy => @drilldown_prefix,
        },
      }

      @query[:aggregations][:drilldown][:terms][:field] = "request_hierarchy"
      @query[:aggregations][:drilldown][:terms][:include] = "#{Regexp.escape(@drilldown_prefix)}.*"
    else
      @drilldown_path_segments.each do |segment|
        @query[:query][:bool][:filter][:bool][:must] << {
          :term => {
            "request_url_hierarchy_level#{segment[:level]}" => "#{segment[:value]}/",
          },
        }
      end

      @query[:aggregations][:drilldown][:terms][:field] = "request_url_hierarchy_level#{@drilldown_depth}"
    end
  end

  def aggregate_by_drilldown_over_time!
    @query[:aggregations][:top_path_hits_over_time] = {
      :terms => {
        :size => 10,
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

    if ApiUmbrellaConfig[:elasticsearch][:template_version] < 2
      @query[:aggregations][:top_path_hits_over_time][:terms][:field] = "request_hierarchy"
      @query[:aggregations][:top_path_hits_over_time][:terms][:include] = "#{Regexp.escape(@drilldown_prefix)}.*"
    else
      @query[:aggregations][:top_path_hits_over_time][:terms][:field] = "request_url_hierarchy_level#{@drilldown_depth}"
    end

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

    if(ApiUmbrellaConfig[:elasticsearch][:api_version] >= 2)
      @query[:aggregations][:top_path_hits_over_time][:aggregations][:drilldown_over_time][:date_histogram].delete(:pre_zone_adjust_large_interval)
      @query[:aggregations][:hits_over_time][:date_histogram].delete(:pre_zone_adjust_large_interval)
    end
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

    if(ApiUmbrellaConfig[:elasticsearch][:api_version] >= 2)
      @query[:aggregations][:hits_over_time][:date_histogram].delete(:pre_zone_adjust_large_interval)
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

  def aggregate_by_country_regions!(country)
    @query[:query][:bool][:filter][:bool][:must] << {
      :term => { :request_ip_country => country },
    }

    aggregate_by_region_field!(:request_ip_region)
  end

  def aggregate_by_us_state_cities!(country, state)
    @query[:query][:bool][:filter][:bool][:must] << {
      :term => { :request_ip_country => country },
    }
    @query[:query][:bool][:filter][:bool][:must] << {
      :term => { :request_ip_region => state },
    }

    aggregate_by_region_field!(:request_ip_city)
  end

  def aggregate_by_country_cities!(country)
    @query[:query][:bool][:filter][:bool][:must] << {
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
    @query[:aggregations][:user_stats] = {
      :terms => {
        :field => :user_id,
        :size => 1_000_000,
      }.merge(options),
      :aggregations => {
        :last_request_at => {
          :max => {
            :field => :request_at,
          },
        },
      },
    }
  end

  def aggregate_by_response_time_average!
    @query[:aggregations][:response_time_average] = {
      :avg => {
        :field => :response_time,
      },
    }
  end

  def select_records!
    # no-op: Method needed for SQL adapters only.
  end

  def none!
    @query[:query][:bool][:filter][:bool][:must] << {
      :bool => {
        :must_not => {
          :match_all => {},
        },
      },
    }
  end

  private

  def indexes
    unless @indexes
      partition_date_format = case ApiUmbrellaConfig[:elasticsearch][:index_partition]
      when "monthly"
        "%Y-%m"
      when "daily"
        "%Y-%m-%d"
      else
        raise "Unknown elasticsearch.index_partition configuration value"
      end

      date_range = @start_time.utc.to_date..@end_time.utc.to_date
      @indexes = date_range.map { |date| "#{ApiUmbrellaConfig[:elasticsearch][:index_name_prefix]}-logs-#{date.strftime(partition_date_format)}" }
      @indexes.uniq!
    end

    @indexes
  end
end
