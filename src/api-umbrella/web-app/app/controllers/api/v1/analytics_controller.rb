class Api::V1::AnalyticsController < Api::V1::BaseController
  include ActionView::Helpers::NumberHelper

  before_action :set_analytics_adapter
  skip_after_action :verify_authorized
  after_action :verify_policy_scoped
  around_action :set_time_zone

  def drilldown
    @search = LogSearch.factory(@analytics_adapter, {
      :start_time => params[:start_at],
      :end_time => params[:end_at],
      :interval => params[:interval],
    })
    policy_scope(@search)

    @search.search!(params[:search])
    @search.query!(params[:query])
    @search.filter_by_date_range!

    drilldown_size = if(request.format == "csv") then 0 else 500 end
    @search.aggregate_by_drilldown!(params[:prefix], drilldown_size)

    if(request.format != "csv")
      @search.aggregate_by_drilldown_over_time!(params[:prefix])
    end

    @result = @search.result

    respond_to do |format|
      format.csv
      format.json do
        @breadcrumbs = [
          :crumb => "All Hosts",
          :prefix => "0/",
        ]

        path = params[:prefix].split("/", 2)[1]
        parents = path.split("/")
        parents.each_with_index do |parent, index|
          @breadcrumbs << {
            :crumb => parent,
            :prefix => File.join((index + 1).to_s, parents[0..index].join("/"), "/"),
          }
        end

        @hits_over_time = {
          :cols => [
            { :id => "date", :label => "Date", :type => "datetime" },
          ],
          :rows => [],
        }

        @result.aggregations["top_path_hits_over_time"]["buckets"].each do |bucket|
          @hits_over_time[:cols] << {
            :id => bucket["key"],
            :label => bucket["key"].split("/", 2).last,
            :type => "number",
          }
        end

        has_other_hits = false
        @result.aggregations["hits_over_time"]["buckets"].each_with_index do |total_bucket, index|
          cells = [
            { :v => total_bucket["key"], :f => formatted_interval_time(total_bucket["key"]) },
          ]

          path_total_hits = 0
          @result.aggregations["top_path_hits_over_time"]["buckets"].each do |path_bucket|
            bucket = path_bucket["drilldown_over_time"]["buckets"][index]
            cells << { :v => bucket["doc_count"], :f => number_with_delimiter(bucket["doc_count"]) }
            path_total_hits += bucket["doc_count"]
          end

          other_hits = total_bucket["doc_count"] - path_total_hits
          cells << { :v => other_hits, :f => number_with_delimiter(other_hits) }

          @hits_over_time[:rows] << {
            :c => cells,
          }

          if(other_hits > 0)
            has_other_hits = true
          end
        end

        if(has_other_hits)
          @hits_over_time[:cols] << {
            :id => "other",
            :label => "Other",
            :type => "number",
          }
        else
          @hits_over_time[:rows].each do |row|
            row[:c].slice!(-1)
          end
        end
      end
    end
  end

  def logs
    # TODO: For the SQL fetching, set start_time to end_time to limit to last
    # 24 hours. If we do end up limiting it to the last 24 hours by default,
    # figure out a better way to document this and still allow downloading
    # the full data set.
    start_time = params[:start_at]
    if(@analytics_adapter == "kylin")
      start_time = Time.zone.parse(params[:end_at]) - 1.day
    end
    @search = LogSearch.factory(@analytics_adapter, {
      :start_time => start_time,
      :end_time => params[:end_at],
      :interval => params[:interval],
    })
    policy_scope(@search)

    offset = params[:start].to_i
    limit = params[:length].to_i
    if(request.format == "csv")
      limit = 500
    end

    @search.search!(params[:search])
    @search.query!(params[:query])
    @search.filter_by_date_range!
    @search.offset!(offset)
    @search.limit!(limit)
    @search.select_records!

    sort = datatables_sort
    if(sort.any?)
      @search.sort!(sort)
    end

    if(request.format == "csv")
      @search.query_options[:search_type] = "scan"
      @search.query_options[:scroll] = "10m"
    end

    @result = @search.result

    respond_to do |format|
      format.json
      format.csv do
        # Set Last-Modified so response streaming works:
        # http://stackoverflow.com/a/10252798/222487
        response.headers["Last-Modified"] = Time.now.utc.httpdate

        headers = ["Time", "Method", "Host", "URL", "User", "IP Address", "Country", "State", "City", "Status", "Reason Denied", "Response Time", "Content Type", "Accept Encoding", "User Agent"]

        send_file_headers!(:disposition => "attachment", :filename => "api_logs (#{Time.now.utc.strftime("%b %-e %Y")}).#{params[:format]}")
        self.response_body = CsvStreamer.new(@result, headers) do |row|
          [
            csv_time(row["request_at"]),
            row["request_method"],
            row["request_host"],
            sanitized_full_url(row),
            row["user_email"],
            row["request_ip"],
            row["request_ip_country"],
            row["request_ip_region"],
            row["request_ip_city"],
            row["response_status"],
            row["gatekeeper_denied_code"],
            row["response_time"],
            row["response_content_type"],
            row["request_accept_encoding"],
            row["request_user_agent"],
            row["request_user_agent_family"],
            row["request_user_agent_type"],
            row["request_referer"],
            row["request_origin"],
          ]
        end
      end
    end
  end

  private

  def sanitized_full_url(record)
    url = "#{record["request_scheme"]}://#{record["request_host"]}#{record["request_path"]}"
    url += "?#{strip_api_key_from_query(record["request_url_query"])}" if(record["request_url_query"])
    url
  end

  def sanitized_url_path_and_query(record)
    url = record["request_path"].to_s.dup
    url += "?#{strip_api_key_from_query(record["request_url_query"])}" if(record["request_url_query"])
    url
  end
  helper_method :sanitized_url_path_and_query

  def strip_api_key_from_query(query)
    stripped = query
    if(query)
      stripped = query.gsub(/\bapi_key=?[^&]*(&|$)/i, "")
      stripped.gsub!(/&$/, "")
    end

    stripped
  end
  helper_method :strip_api_key_from_query
end
