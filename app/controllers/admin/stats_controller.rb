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
    @search.limit!(500)

    @result = @search.result
  end

  def users
    @search = LogSearch.new({
      :start_time => params[:start],
      :end_time => params[:end],
      :interval => params[:interval],
    })

    @search.filter_by_date_range!
    @search.facet_by_interval!
    @search.facet_by_users!(500)

    @result = @search.result
  end

  def map
    @search = LogSearch.new({
      :start_time => params[:start],
      :end_time => params[:end],
      :region => params[:region],
    })

    @search.filter_by_date_range!
    @search.facet_by_region!

    @result = @search.result
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
