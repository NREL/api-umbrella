class Admin::StatsController < Admin::BaseController
  set_tab :analytics

  around_filter :set_time_zone

  def index
  end

  def map
  end

  def data
    @start_time = Time.zone.parse(params[:start])
    @end_time = Time.zone.parse(params[:end]).end_of_day
    if(@end_time > Time.zone.now)
      @end_time = Time.zone.now
    end

    date_range = @start_time.utc.to_date..@end_time.utc.to_date
    indexes = date_range.map { |date| "api-umbrella-logs-#{date.iso8601}" }

    # Compact the list of indexes by using wildcards for full months. This
    # helps trim down the URL length when indexes get passed to elasticsearch.
    # Otherwise, it's easy to bump elasticsearch's HTTP length limits for GET
    # URLs.
    #
    # If we still run into issues, we could actually tweak Elasticsearch's
    # allowable HTTP sizes:
    # https://github.com/elasticsearch/elasticsearch/issues/1174
    if(indexes.length > 28)
      month = date_range.min.beginning_of_month
      while(month < date_range.last)
        month_range = month..month.end_of_month
        if(month_range.min >= date_range.min && month_range.max <= date_range.max)
          index_prefix = "api-umbrella-logs-#{month.strftime("%Y-%m")}-"
          indexes.reject! { |index| index.start_with?(index_prefix) }
          indexes << "#{index_prefix}*"
        end

        month += 1.month
      end
    end

    #server = Stretcher::Server.new("http://10.20.5.139:9200", :logger => Logger.new("/tmp/blah.log"))
    server = Stretcher::Server.new("http://127.0.0.1:9200", :logger => Logger.new("/tmp/blah.log"))

    @result = server.index(indexes.join(",")).search(search_options, search_query)
    @hits = {}

    if(params[:interval].present?)
      fill_in_missing_intervals
    end

    user_ids = @result.facets[:user_id][:terms].map { |term| term[:term] }
    user_ids += @result.results.map { |result| result[:user_id] }
    @users = ApiUser.where(:_id.in => user_ids).all.to_a.group_by { |user| user.id.to_s }
    @result.results.each do |result|
      if @users[result[:user_id]]
        user = @users[result[:user_id]].first
        result[:email] = user.email
      end
    end

    @result.facets[:user_id][:terms].each do |term|
      if @users[term[:term]]
        user = @users[term[:term]].first
        term[:term] = user.email
      end
    end

    @result.facets[:response_status][:terms].each do |term|
      name = Rack::Utils::HTTP_STATUS_CODES[term[:term].to_i]
      if(name)
        term[:term] = "#{term[:term]} (#{name})"
      end
    end

    if(params[:interval].present?)
      @result.facets[:histo1][:entries].each do |entry|
        @hits[entry[:time]] = entry[:count]
      end
    end

    if(params[:region].present?)
      @regions = @result.facets[:regions][:terms]
      if(@query[:facets][:regions][:terms][:field] == "request_ip_city")
        @city_names = @regions.map { |term| term[:term] }
        @cities = {}

        if @city_names.any?
          query = {
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
          }

          query[:query][:filtered][:filter][:and] << {
            :term => { :country => @country },
          }

          if @region
            query[:query][:filtered][:filter][:and] << {
              :term => { :region => @region },
            }
          end

          query[:query][:filtered][:filter][:and] << {
            :terms => { :city => @city_names },
          }

          server.index("api-umbrella").search({ :size => 500 }, query).results.each do |result|
            @cities[result[:city]] = result[:location]
          end
        end
      end
    end
  end

  private

  def set_time_zone
    old_time_zone = Time.zone
    if(params[:tz].present?)
      Time.zone = params[:tz]
    end

    yield
  ensure
    Time.zone = old_time_zone
  end

  def search_options
    {
      :size => 25,
      :ignore_indices => "missing",
    }
  end

  def search_query
    @query = {
      :query => {
        :filtered => {
          :query => {
            :match_all => {},
          },
          :filter => {
            :and => [
              {
                :range => {
                  :request_at => {
                    :from => @start_time.iso8601,
                    :to => @end_time.iso8601,
                  },
                },
              },
            ],
            #:term => { :response_content_type => "application/json" },
          },
        },
      },
      :sort => {
        :request_at => {
          :order => "desc",
        },
      },
      :facets => {
        :response_status => {
          :terms => {
            :field => "response_status",
            :size => 4,
          },
        },
        :response_content_type => {
          :terms => {
            :field => "response_content_type",
            :size => 4,
          },
        },
        :request_method => {
          :terms => {
            :field => "request_method",
            :size => 4,
          },
        },
        :request_ip => {
          :terms => {
            :field => "request_ip",
            :size => 4,
          },
        },
        :user_id => {
          :terms => {
            :field => "user_id",
            :size => 4,
          },
        },
      },
    }

    if(params[:interval].present?)
      @query[:facets][:histo1] = {
        :date_histogram => {
          :field => "request_at",
          :interval => params[:interval],
          :all_terms => true,
          :time_zone => Time.zone.name,
          :pre_zone_adjust_large_interval => true,
        },
      }
    end

    if(params[:region].present?)
      @map_breadcrumbs = []

      case(params[:region])
      when "world"
        @query[:facets][:regions] = {
          :terms => {
            :field => "request_ip_country",
            :size => 250,
          },
        }
      when "US"
        @country = params[:region]

        @query[:query][:filtered][:filter][:and] << {
          :term => { :request_ip_country => @country },
        }

        @query[:facets][:regions] = {
          :terms => {
            :field => "request_ip_region",
            :size => 250,
          },
        }
      when /^(US)-([A-Z]{2})$/
        @country = $1
        @region = $2

        @map_breadcrumbs = [
          { :region => "world", :name => "World" },
          { :region => @country, :name => Country[@country].name },
          { :name => Country[@country].states[@region]["name"] },
        ]

        @query[:query][:filtered][:filter][:and] << {
          :term => { :request_ip_country => @country },
        }
        @query[:query][:filtered][:filter][:and] << {
          :term => { :request_ip_region => @region },
        }

        @query[:facets][:regions] = {
          :terms => {
            :field => "request_ip_city",
            :size => 250,
          },
        }
      else
        @country = params[:region]

        @query[:query][:filtered][:filter][:and] << {
          :term => { :request_ip_country => @country },
        }

        @query[:facets][:regions] = {
          :terms => {
            :field => "request_ip_city",
            :size => 250,
          },
        }
      end

      if(params[:region] =~ /^[A-Z]{2}$/)
        @map_breadcrumbs = [
          { :region => "world", :name => "World" },
          { :name => Country[params[:region]].name },
        ]
      end
    end

    @query
  end

  def fill_in_missing_intervals
    time = @start_time
    case params[:interval]
    when "minute"
      time = time.change(:sec => 0)
    when "hour"
      time = time.beginning_of_hour
    when "day"
      time = time.beginning_of_day
    when "week"
      time = time.beginning_of_week
    when "month"
      time = time.beginning_of_month
    end

    while(time <= @end_time)
      @hits[time.to_i * 1000] = 0

      case params[:interval]
      when "minute"
        time += 1.minute
      when "hour"
        time += 1.hour
      when "day"
        time += 1.day
      when "week"
        time += 1.week
      when "month"
        time += 1.month
      end
    end
  end
end
