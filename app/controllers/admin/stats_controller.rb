class Admin::StatsController < Admin::BaseController
  set_tab :analytics

  def index
  end

  def data
    start_time = (Time.now - 5.months).utc
    end_time = Time.now.utc
    date_range = start_time.to_date..end_time.to_date

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

    interval = "day"

    server = Stretcher::Server.new("http://devdev-db.nrel.gov:9200", :logger => Logger.new("/tmp/blah.log"))
    @result = server.index(indexes.join(",")).search({
      :size => 50,
      :ignore_indices => "missing",
    }, {
      :query => {
        :match_all => {},
        #:term => { :response_content_type => "application/json" },
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
        :histo1 => {
          :date_histogram => {
            :field => "request_at",
            :interval => interval,
            :all_terms => true,
          },
        },
      },
    })

    @hits = {}

    time = start_time
    case interval
    when "hour"
      time = time.beginning_of_hour
    when "day"
      time = time.beginning_of_day
    end

    while(time <= end_time)
      @hits[time.to_i * 1000] = 0

      case interval
      when "hour"
        time += 1.hour
      when "day"
        time += 1.day
      end
    end

    user_ids = @result.facets[:user_id][:terms].map { |term| term[:term] }
    user_ids += @result.results.map { |result| result[:user_id] }
    @users = ApiUser.where(:_id.in => user_ids).all.to_a.group_by { |user| user.id.to_s }

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

    @result.facets[:histo1][:entries].each do |entry|
      @hits[entry[:time]] = entry[:count]
    end
  end
end
