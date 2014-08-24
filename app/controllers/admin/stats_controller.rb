require "csv_streamer"

class Admin::StatsController < Admin::BaseController
  set_tab :analytics

  around_filter :set_time_zone

  def index
  end

  def search
    @search = LogSearch.new({
      :start_time => params[:start],
      :end_time => params[:end],
      :interval => params[:interval],
    })

    @search.search!(params[:search])
    @search.filter_by_date_range!
    @search.facet_by_interval!
    @search.facet_by_users!(10)
    @search.facet_by_response_status!(10)
    @search.facet_by_response_content_type!(10)
    @search.facet_by_request_method!(10)
    @search.facet_by_request_ip!(10)
    @search.facet_by_request_user_agent_family!(10)
    @search.facet_by_response_time_stats!
    @search.limit!(1)

    @result = @search.result
  end

  def logs
    @search = LogSearch.new({
      :start_time => params[:start],
      :end_time => params[:end],
      :interval => params[:interval],
    })

    offset = params["iDisplayStart"].to_i
    limit = params["iDisplayLength"].to_i
    if(request.format == "csv")
      limit = 500
    end

    @search.search!(params[:search])
    @search.filter_by_date_range!
    @search.offset!(offset)
    @search.limit!(limit)

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
        response.headers["Last-Modified"] = Time.now.httpdate

        scroll_id = @result.raw_result.raw_plain["_scroll_id"]
        headers = ["Time", "Method", "Host", "URL", "User", "IP Address", "Country", "State", "City", "Status", "Response Time", "Content Type", "Accept Encoding", "User Agent"]

        send_file_headers!(:disposition => "attachment", :filename => "api_logs (#{Time.now.strftime("%b %-e %Y")}).#{params[:format]}")
        self.response_body = CsvStreamer.new(scroll_id, headers) do |row|
          [
            Time.parse(row["request_at"]).utc.strftime("%Y-%m-%d %H:%M:%S"),
            row["request_method"],
            row["request_host"],
            row["request_url"],
            row["user_email"],
            row["request_ip"],
            row["request_ip_country"],
            row["request_ip_region"],
            row["request_ip_city"],
            row["response_status"],
            row["response_time"],
            row["response_content_type"],
            row["request_accept_encoding"],
            row["request_user_agent"],
          ]
        end
      end
    end
  end

  def users
    @search = LogSearch.new({
      :start_time => params[:start],
      :end_time => params[:end],
    })

    offset = params["iDisplayStart"].to_i
    limit = params["iDisplayLength"].to_i
    if(request.format == "csv")
      limit = 100_000
    end

    sort = datatables_sort.first
    sort_field = sort.keys.first if(sort)
    sort_direction = sort.values.first if(sort)

    # If we're sorting by hits or last request date, then we can perform the
    # sorting directly in the elasticsearch query. Otherwise, for user-based
    # field, we'll need to defer sorting until we have all the results in ruby.
    facet_options = {}
    if sort
      case(sort_field)
      when "hits"
        facet_options[:order] = "count"
      when "last_request_at"
        facet_options[:order] = "max"
      end

      if(facet_options[:order] && sort_direction == "asc")
        facet_options[:order] = "reverse_#{facet_options[:order]}"
      end
    end

    @search.search!(params[:search])
    @search.filter_by_date_range!
    @search.facet_by_user_stats!(facet_options)

    @result = @search.result
    @total = @result.facets["user_stats"]["terms"].length

    terms = @result.facets["user_stats"]["terms"]

    # If we were sorting by one of the facet fields, then the sorting has
    # already been done by elasticsearch. We can improve the performance by
    # going ahead and truncating the results to the specified page.
    if(facet_options[:order])
      terms = terms.slice(offset, limit)
    end

    user_ids = terms.map { |term| if(term) then term["term"] else nil end }
    users_by_id = ApiUser.where(:_id.in => user_ids).all.to_a.group_by { |user| user.id.to_s }

    # Build up the results, combining the stats facet information with the user
    # details.
    @user_data = []
    terms.map do |term|
      user = {}
      if(users_by_id[term["term"]])
        user = users_by_id[term["term"]].first.attributes
      end

      @user_data << {
        :id => term["term"],
        :email => user["email"],
        :first_name => user["first_name"],
        :last_name => user["last_name"],
        :website => user["website"],
        :registration_source => user["registration_source"],
        :created_at => user["created_at"],
        :hits => term["count"],
        :last_request_at => Time.at(term["max"] / 1000),
        :use_description => user["use_description"],
      }
    end

    # If sorting was on any of the user fields, now that we have a full result
    # set now we can manually sort and paginate.
    if(!facet_options[:order])
      @user_data.sort_by! { |user| user[:"#{sort_field}"].to_s }
      if(sort_direction == "desc")
        @user_data.reverse!
      end

      @user_data = @user_data.slice(offset, limit)
    end

    respond_to do |format|
      format.json
      format.csv
    end
  end

  def map
    @search = LogSearch.new({
      :start_time => params[:start],
      :end_time => params[:end],
      :region => params[:region],
    })

    @search.search!(params[:search])
    @search.filter_by_date_range!
    @search.facet_by_region!

    @result = @search.result

    respond_to do |format|
      format.json
      format.csv
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
end
