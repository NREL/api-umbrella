class Api::HealthChecksController < ApplicationController
  def ip
    render(:json => { :ip => request.ip })
  end

  def logging
    @search = LogSearch.new({
      :start_time => Time.now - params[:age].to_i,
      :end_time => Time.now,
    })

    @search.filter_by_date_range!
    @search.filter_by_api_key!(params[:user_key])
    @search.filter_by_request_path!("/api/health-checks/logging")
    @search.limit!(1)
    @result = @search.result

    healthy = false
    if(@result.total >= params[:min_results].to_i)
      result = @result.results.first

      if(result)
        # Make sure logging details from the gatekeeper are present.
        if(result["internal_gatekeeper_time"] && result["internal_gatekeeper_time"] > 0)
          # Make sure logging details from the router are present.
          if(result["backend_response_time"] && result["backend_response_time"] > 0)
            healthy = true
          end
        end
      end
    end

    render(:json => {
      :healthy => healthy,
      :count => @result.total,
    })
  end
end
